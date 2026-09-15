# Content-Gap Reports Store Only `subject_code`, Which Is Not Unique Per Grade

**Date:** 2026-09-15
**Project:** HBEC
**Environment:** Development
**Severity:** Medium
**Status:** Investigating (found during read-only research for a planned
"Grade" column + "go to subject" link on the admin Content Requests table;
no code changed this session — the requester explicitly asked for research
only)

## Summary
`ContentGapReport` (`NOTIFICATIONS/app/notifications/models.py`) — the table
behind the admin "Content Requests" page — stores only `subject_code` and
`pillar`, never a grade, exam board, or Subject UUID. Both the admin backend
(`ADMIN/adminBackend/apps/curriculum/models.py`, `Subject`) and the student
backend (`STUDENT/hbec_backend/apps/curriculum/models.py`, `Subject`)
explicitly document and enforce that a bare `code` is **not** unique per
subject — it repeats across every grade a subject family is offered at (e.g.
ZIMSEC primary codes 701-707 shared across a grade band; "pure-mathematics"
existing once for form-5 and again for form-6). The real unique key is
`(code, grade)` on the student side (`subject_code_grade_code_unique`
constraint) and `(family, grade)` / `(exam_board, grade, code)` on the admin
side.

The admin Content Requests table
(`ADMIN/adminFrontend/src/features/content-requests/pages/ContentRequestsPage.tsx:44-50`)
resolves `subject_code` to a display name via:

```ts
const subjectNameByCode = useMemo(() => {
  const map = new Map<string, string>();
  for (const subject of subjects ?? []) {
    map.set(subject.code, subject.name);
  }
  return map;
}, [subjects]);
```

This assumes one name per code. Whenever two `Subject` rows share a `code`
(the documented normal case for phase-spanning and primary subjects), the
`Map` silently keeps whichever row came last in the `subjects` array —
there is no guarantee it's the grade the student who filed the report was
actually looking at. The same ambiguity blocks adding a "Grade" column or a
"go to this subject" link the straightforward way: `subject_code` alone
cannot be resolved back to one `(SubjectFamily, Grade)` pair, so there is no
single admin-subject-page URL to send the admin to.

## Symptoms
- No user-visible symptom yet observed in production data — this is a
  design-level gap found by tracing the data model, not a reported incident.
- Latent risk: a subject code that legitimately repeats across two different
  grades (or, in the worst case, two unrelated subject families that happen
  to reuse the same code string at different grades — nothing prevents this
  across families) would let `ContentRequestsPage.tsx`'s subjectNameByCode
  map display the wrong subject name for one of them, non-deterministically
  based on array order.
- Directly blocks the planned "Grade" column and per-subject "add content"
  deep link on the Content Requests page: there is no grade-disambiguating
  field anywhere in the pipeline from student report → `ContentGapReport` row
  → admin summary API → admin frontend row.

## Environment Details
- **Server/Host:** local dev / codebase research, `/home/shadowe/Projects/HBEC`
- **Services Affected:** `NOTIFICATIONS` (FastAPI, `content_gap_reports`
  table), `ADMIN/adminFrontend` (`content-requests` feature)
- **Related Components:** `ADMIN/adminBackend/apps/curriculum` (`Subject`,
  `SubjectFamily`, `Grade`), `STUDENT/hbec_backend/apps/curriculum`
  (`Subject.grade_code`), `STUDENT/Frontend` (`contentGapApi.ts`,
  `PaperListingPage.tsx`, `SubjectContentPage.tsx`)
- **Time First Observed:** 2026-09-15, codebase research session

## Investigation Steps

### 1. Initial Diagnosis
Traced the admin "Content Requests" table
(`ADMIN/adminFrontend/src/features/content-requests/pages/ContentRequestsPage.tsx`)
back through `contentRequestsApi.ts` → NOTIFICATIONS service
(`app/notifications/router_content_gap.py`, `schemas.py`, `models.py`) to
find what identifying data a "Grade" column and a per-subject admin link
could reuse.

### 2. Root Cause Analysis
- `ContentGapReport` (`NOTIFICATIONS/app/notifications/models.py:49-93`)
  stores `subject_code: str`, `pillar: str`, `student_user_id`,
  `reported_at` — no grade, no exam board, no Subject UUID.
- The student frontend already has everything needed at report time but
  never sends it: `PaperListingPage.tsx:35` and
  `SubjectContentPage.tsx:230` call
  `reportContentGap(subjectData.syllabusCode, pillar)`, discarding the rest
  of the matched `Subject` object. `contentGapApi.ts:32` only accepts
  `(subjectCode, pillar)`.
- `STUDENT/hbec_backend/apps/curriculum/models.py:222-227` and the
  `subject_code_grade_code_unique` constraint at line 265-268 document
  explicitly that `code` alone is not unique — "admin authors one Subject
  row per specific grade, and reuses the same code across grades for a
  subject that spans a phase."
- `ADMIN/adminBackend/apps/curriculum/models.py:89-160` (`Subject`) confirms
  the same on the admin side:
  `test_same_code_reusable_across_grades`
  (`ADMIN/adminBackend/apps/curriculum/tests/test_models.py:34-45`) creates
  two `Subject` rows with `code="MATH"` under the same family at two
  different grades and asserts both exist.
- The admin frontend's own `Subject` type
  (`ADMIN/adminFrontend/src/features/curriculum/types/index.ts:206-222`)
  already carries `id`, `examBoardId`, `gradeId`, and a full
  `grade: {id, name, code, phase}` object per subject — `useSubjects()`
  fetches this today — but `ContentRequestsPage.tsx` discards everything
  except `.name`, keyed by the ambiguous `.code`.

## Root Cause
A join key (`subject_code`) that both backends explicitly document as
non-unique-per-grade is being used as if it uniquely identified a subject,
because the one table that would need the disambiguating field
(`ContentGapReport`) was designed before (or without reference to) the
`SubjectFamily`/per-grade-`Subject` split, and the student-side call sites
that create these rows have the grade-scoped `Subject` object in hand but
never forward any of its grade-identifying fields.

## Prevention / Rule
**Guardrail:** Any new table that stores a reference to a `Subject`-like
entity must store the entity's primary key (or `(code, grade)` /
`(family_id, grade_id)` pair), never a bare `code` alone — enforce via a
code-review checklist item ("does this FK/reference disambiguate by grade
where `Subject.code` is known to repeat?") until it can be a lint rule (e.g.
a repo grep for new model fields named `subject_code`/`*_code` without an
adjacent `grade`/`grade_code`/`subject_id` field in the same migration).

This closes the gap because the underlying cause is structural (a schema
missing a field), not a one-off logic mistake — the same non-unique-`code`
trap has already required a data backfill once before on the admin side
(see `Database_and_State/HBEC-2026-09-11-*` and
`HBEC-2026-...-legacy-subject-code-constraint-removal-*` in this repo) and
will keep recurring wherever a new feature reaches for `Subject.code` as if
it were a primary key.

## Solution

### Immediate Fix
None applied — this was a read-only research pass for planning purposes
only, at the requester's explicit instruction. No code was changed.

### Long-term Fix (not yet implemented — for planning)
- Add a grade-disambiguating field to `ContentGapReport` (e.g.
  `subject_id: UUID` referencing the admin `Subject.id` that was replicated
  to the student backend, or at minimum `grade_code: str`), captured from
  the already-available `Subject` object at the two report call sites
  (`PaperListingPage.tsx`, `SubjectContentPage.tsx`) instead of only
  `syllabusCode`.
- Requires an alembic migration on the NOTIFICATIONS service DB, a
  `ContentGapReportCreate`/`ContentGapSummaryOut` schema change
  (`app/notifications/schemas.py`), and threading the new field through
  `router_content_gap.py`'s insert and aggregate-group-by query.
- Once present, `ContentRequestsPage.tsx` can resolve to one exact `Subject`
  row (not just a name) and link to
  `/exam-boards/:boardId/grades/:gradeId/subjects/:subjectId`
  (`ADMIN/adminFrontend/src/App.tsx:59-64`, `SubjectPage.tsx`) using that
  Subject's `examBoardId`, `gradeId`, and `id` — all three of which
  `useSubjects()` already returns per subject today.

## Prevention
- [ ] Schema change: add `subject_id` or `grade_code` to `ContentGapReport`
- [ ] Update both report call sites to send the new field
- [ ] Update `ContentRequestsPage.tsx`'s lookup to key on `(code, grade)`
      or a Subject id instead of bare `code`
- [x] Documentation: this entry
- [ ] Code-review checklist item per the Guardrail above

## Related Issues
- `Database_and_State/HBEC-2026-09-11-*` (secondary subject dedup /
  add-grades-to-existing-syllabus) and the legacy subject-code
  constraint-removal entry — same non-unique-`Subject.code` root cause
  surfacing in a different feature.

## References
- `NOTIFICATIONS/app/notifications/models.py` (`ContentGapReport`)
- `NOTIFICATIONS/app/notifications/router_content_gap.py`
- `NOTIFICATIONS/app/notifications/schemas.py`
- `ADMIN/adminFrontend/src/features/content-requests/pages/ContentRequestsPage.tsx`
- `ADMIN/adminFrontend/src/features/content-requests/types/index.ts`
- `ADMIN/adminFrontend/src/features/content-requests/api/contentRequestsApi.ts`
- `ADMIN/adminBackend/apps/curriculum/models.py` (`Subject`, `SubjectFamily`, `Grade`)
- `ADMIN/adminBackend/apps/curriculum/tests/test_models.py`
- `STUDENT/hbec_backend/apps/curriculum/models.py` (`Subject`)
- `STUDENT/Frontend/src/lib/contentGapApi.ts`
- `STUDENT/Frontend/src/features/exam-practice/pages/PaperListingPage.tsx`
- `STUDENT/Frontend/src/features/topic-revision/pages/SubjectContentPage.tsx`
- `ADMIN/adminFrontend/src/App.tsx` (route
  `/exam-boards/:boardId/grades/:gradeId/subjects/:subjectId`)

---

**Resolved By:** N/A — logged by Claude Code during read-only research
(not yet fixed)
**Time to Resolution:** N/A
