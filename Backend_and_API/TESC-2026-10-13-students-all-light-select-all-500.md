# Institution Portal "select all" students crashed with 500 on all-light endpoint

**Date:** 2026-10-13
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The "select all" checkbox on the Institution Portal's Students Directory
(`inst/src/pages/Students.tsx`) silently did nothing. Its only data source,
`GET /academic/students/all-light/`, returned a 500 on every single request
due to a Django `FieldError` - chaining `.only()` with a field list that
didn't account for every relation the underlying `self.get_queryset()`
already `select_related()`s.

## Symptoms
- Institution Portal, Students Directory page: clicking the header checkbox
  (or Ctrl/Cmd+A) to select all students did nothing - no rows got checked,
  no visible error in the UI.

## Environment Details
- **Server/Host:** tesc-staging VM, `tesc-backend-1` container
- **Services Affected:** `backend/academic/app_views/student_views.py`
  (`StudentViewSet.all_light`)
- **Related Components:** `inst/src/pages/Students.tsx` (`toggleSelectAll`),
  `inst/src/hooks/queries/useStudents.ts` (`useAllStudents`),
  `inst/src/services/students.services.ts` (`getAllFilteredStudents`)
- **Time First Observed:** 2026-10-13, user-reported while testing the
  newly-seeded institution admin account.

## Investigation Steps

### 1. Initial Diagnosis
Traced the frontend call chain: `toggleSelectAll` ->
`fetchAllFilteredStudents()` (a `useAllStudents` query's `refetch`) ->
`studentService.getAllFilteredStudents` -> `GET
/academic/students/all-light/`. Called the backend action directly via
`APIRequestFactory` + `force_authenticate` against the real institution
admin account created this session - got a 500 immediately, with a full
traceback (not caught/swallowed anywhere, since this is a direct
`Response` return, not going through a try/except).

### 2. Root Cause Analysis
The traceback:
```
django.core.exceptions.FieldError: Field Student.faculty cannot be both
deferred and traversed using select_related at the same time.
```
`all_light()` builds its queryset from `self.get_queryset()`, whose base
implementation (same method, lines ~155-158) already applies
`select_related('institution', 'program', 'faculty', 'department',
'inclusivity_profile', 'work_for_fees_profile', 'iseop_profile')`.
`all_light()` then chained its own `.select_related('institution',
'program', 'inclusivity_profile').only(<10-ish field list>)` on top -
`.only()`'s field list didn't include `faculty`, `department`,
`work_for_fees_profile`, or `iseop_profile`, which Django considers an
invalid combination once those relations are already select-related.

### 3. Key Findings
- This endpoint is the *only* thing backing "select all" - there's no
  fallback path, so the bug was a hard, total failure of that one feature,
  not a degraded/partial one.
- The codebase already has two other comments (in `search_students` in the
  same file, and in `backend/staff/views/staff_viewset.py`) explicitly
  flagging this exact `.only()` + inherited `select_related()` conflict as
  a known gotcha and working around it - `all_light()` was the one place
  that didn't apply that same care, likely added after those other two
  fixes without reusing the lesson.
- Checked the rest of the codebase (`grep` for `.only(`) for the same
  pattern - no other instance found.

## Root Cause
`StudentViewSet.all_light()` layered a `.only()` field-restriction on top
of a base queryset (`self.get_queryset()`) that already `select_related()`s
more relations than `.only()`'s field list accounted for, which Django
rejects outright as an invalid queryset.

## Prevention / Rule
**Guardrail:** any new `@action` on `StudentViewSet` (or any other viewset
whose `get_queryset()` applies its own `select_related()`) that wants to
narrow fields via `.only()` must either (a) build its queryset from scratch
rather than `self.get_queryset()`, or (b) include every field needed by
every relation the base queryset already select-related's. A quick
smoke-test hitting every custom `@action` endpoint with a real
authenticated request (not just the standard list/retrieve/create/update/
delete actions) as part of CI would have caught this immediately, since
the 500 happens on the very first request regardless of data or filters.

This closes the gap because the failure is deterministic and
data-independent - any test that actually calls the endpoint, with any
user, catches it; the bug survived only because nothing did.

## Solution

### Immediate Fix
Removed the redundant `.select_related()`/`.only()` chain in `all_light()`
- `self.get_queryset()` already provides every relation needed, and the
response-building loop already projects each row down to a plain dict with
only the fields it needs, so `.only()` had no remaining memory benefit to
preserve once removed.

```bash
# Verified via APIRequestFactory + force_authenticate against the real
# institution-scoped admin account created this session:
# before: 500, FieldError
# after: 200, 195 correctly institution-scoped students returned
```

### Long-term Fix
None needed - the fix is a straightforward removal of an unnecessary,
broken optimization.

## Prevention
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — alert on 500 rate from
      `/academic/students/all-light/` and other custom `@action` endpoints.
- [ ] Documentation to update — none.
- [x] Code changes required — done (see Solution).

## Related Issues
- None directly, though this is the same general bug *class* (a
  `.select_related()`/field-restriction interaction) that `search_students`
  and `staff_viewset.py` already defend against elsewhere in the codebase.

## References
- `backend/academic/app_views/student_views.py`
- `inst/src/pages/Students.tsx`
- `inst/src/hooks/queries/useStudents.ts`
- `inst/src/services/students.services.ts`
- Commit: `56c831f` on `staging`.

---

**Resolved By:** tinomupezeni (with Claude Sonnet 5)
**Time to Resolution:** ~20 minutes
