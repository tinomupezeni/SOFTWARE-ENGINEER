# Students Filtering: Grade and Subject Filters

**Date:** 2026-10-27
**Project:** HBCA (HBEC repo)
**Type:** Feature
**Status:** Completed (staging only)

## Summary
Added grade and subject filters to the admin's student management list,
closing out the HBCA task "Students Filtering" ("Allow admin to apply
several different filters for students i.e. level, subject,
subscription") — subscription and status filters already existed; grade
and subject did not.

## Context / Trigger
HBCA ProjectFlow task "Students Filtering" (TODO, MEDIUM), found while
reviewing the HBCA project's open task board after a session of chat-driven
bug fixes.

## Scope
Admin-visible student list filtering only — the existing `StudentTable` /
`StudentCard` display and all other student-management actions (reset
password, delete, convert to parent, etc.) are unchanged. "Level" in the
task description is implemented as the existing `StudentProfile.grade`
field (e.g. "Form 3"), matching the vocabulary and real-column approach
already used by the bulk-email audience picker's "select specific grades"
mode, rather than introducing a second, differently-scoped "level" concept.

## Method
Traced the existing student list pipeline end to end: Admin Frontend
(`StudentManagementPage.tsx`) → Admin Backend proxy (`StudentListView`,
`student_management/views.py`) → Student Backend's internal
`StudentUserListView` (`apps/internal/views.py`), which does the actual
Django queryset filtering against `apps.accounts.models.User`/
`StudentProfile`. Found the precedent for "offer only real, present
values" already established by `User.bulk_email_grade_options()` — its own
docstring explains why grade options must come from the real column rather
than a separately-maintained list (drift risk). Followed the same
reasoning for both grade and the new subject-options case.

## Decisions & Findings
- Reused the real-column approach (`User.grade_options()` /
  `User.subject_options()`, new classmethods on `User`) rather than
  sourcing options from the curriculum `Subject`/`Grade` catalogues, since
  `StudentProfile.grade`/`.subjects` are free values a student
  typed/picked, not FK-validated, and can drift from the catalogue.
- `grade_options()` deliberately does NOT reuse `bulk_email_recipients()`
  (which is `is_active=True` only) — the Students Filtering grade dropdown
  needs to offer grades for inactive students too, since the page's
  active/inactive filter is independent of the grade filter.
- Subject filtering matches "student's subject list contains this value"
  (`student_profile__subjects__contains=[subject]`), since `subjects` is a
  JSON list a student can have several of, unlike the single-valued
  `grade`.

## Changes Made
- `STUDENT/hbec_backend/apps/accounts/models.py`: added `User.grade_options()`
  and `User.subject_options()` classmethods.
- `STUDENT/hbec_backend/apps/internal/views.py`: `StudentUserListView.get`
  now accepts `grade` (exact match) and `subject` (list-contains) query
  params; added `StudentFilterOptionsView` returning both option lists.
- `STUDENT/hbec_backend/apps/internal/urls.py`: wired
  `users/filter-options/`.
- `ADMIN/adminBackend/apps/student_management/views.py`: `StudentListView`
  forwards `grade`/`subject`; added `StudentFilterOptionsView` proxy.
- `ADMIN/adminBackend/apps/student_management/urls.py`: wired
  `filter-options/`.
- `ADMIN/adminFrontend/src/features/student-management/`: added `grade`/
  `subject` to `StudentQueryParams`, a `StudentFilterOptions` type, the
  `getStudentFilterOptions` API call, a `useStudentFilterOptions` hook
  (5-minute `staleTime` — these options change rarely), and two new
  dropdowns on `StudentManagementPage` alongside the existing status/
  subscription/role filters.

## Verification
- Backend: new test file `test_student_filter_by_grade_subject.py` (4
  tests: exact grade match, subject-list-contains match, a profile-less
  student matches neither filter, and the options endpoint lists every
  distinct value) — all passing against a throwaway local Postgres+Redis,
  alongside the full `apps/internal/tests/` suite (189 passed; 4
  pre-existing failures in unrelated files — `service_signature.py`
  byte-identity check and `sync-student` auth status codes — confirmed
  unrelated to this change).
- Frontend: new `studentApi.test.ts` (3 tests: grade/subject forwarded in
  the query string, grade/subject omitted when unset, filter-options
  parsed correctly) plus the full `student-management` suite (16 tests) —
  all passing. `tsc --noEmit` clean; `eslint` shows only pre-existing
  warnings in files this change didn't touch the relevant lines of.

## Follow-ups / Deferred
- Not yet deployed to production (staging only, pending cutover alongside
  the other HBCA fixes from this session).
- `grade`/`subject` filters currently only make sense when `role=student`
  (parents have no `StudentProfile`); not explicitly disabled when
  `role=parent`/`all` is selected, since selecting a grade/subject while
  viewing parents would simply return no results rather than erroring —
  acceptable for now, worth a UX pass if it proves confusing in practice.

## References
- HBCA ProjectFlow task "Students Filtering".
- `User.bulk_email_grade_options()` (precedent for the real-column
  options approach), `apps/student_management/views.py`
  `BulkEmailGradeOptionsView` (precedent for the proxy-endpoint shape).

---

**Completed By:** Tinotenda Mupezeni (with Claude Code)
**Duration:** ~1 hour
