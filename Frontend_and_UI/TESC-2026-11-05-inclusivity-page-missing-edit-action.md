# Inclusivity page had no way to edit an existing student's inclusivity category

**Date:** 2026-11-05
**Project:** TESC (ScalarEye)
**Environment:** Production/Staging (institution frontend, `inst/`)
**Severity:** Medium
**Status:** Resolved

## Summary
Institution users reported they couldn't change a student's inclusive
(disability) category. The field is fully editable end-to-end in the
general student-edit flow, but the dedicated Inclusivity page
(`inst/src/pages/Inclusivity.tsx`) only rendered an "Add Student" dialog
over its table — there was no edit action on existing rows, so a user
viewing a student via that page had no way to update their category short
of finding the same student again on the main Students page.

## Symptoms
- Users on the Inclusivity Report page could view and add inclusivity
  records but had no visible way to edit an existing student's category.

## Environment Details
- **Server/Host:** N/A (frontend-only)
- **Services Affected:** `inst` (institution admin) frontend
- **Related Components:** `EditStudentDialog.tsx`, `AddStudentDialog.tsx`
  (`isInclusivityMode`), `students.services.ts`
- **Time First Observed:** 2026-11-05, reported by user

## Investigation Steps

### 1. Initial Diagnosis
Traced the full stack for the `inclusivity_category` field end-to-end
before touching any code: Django model (`StudentInclusivity.category`),
DRF serializer (`write_only`, not `read_only`, included in both
create/update `fields`), `StudentService.update_student` (persists via
create/update/delete of the related row), and the view's `perform_update`
(passes `validated_data` through unmodified). All of it was already
correct and writable.

### 2. Root Cause Analysis
With the backend and the general edit form (`EditStudentDialog.tsx`)
confirmed clean, checked the Inclusivity-specific page itself
(`inst/src/pages/Inclusivity.tsx`). Its table (lines 168-207, prior to fix)
rendered student rows with no actions column — only `AddStudentDialog`
(`isInclusivityMode={true}`) existed on the page, for creating new
inclusivity records, never for editing existing ones.

### 3. Key Findings
- Backend, serializer, service, and the Students-page edit dialog were all
  already correct — the bug was a missing UI affordance on one specific
  page, not a data/permissions/validation bug.
- The page's `InclusivityStudent` list type is a lightweight summary (id,
  name, program, gender, category, institution). The first pass of the fix
  fetched the full `NormalizedStudent` record via `getStudentById` and
  reused the full `EditStudentDialog` form; on review this was replaced
  with a purpose-built, minimal dialog (see Solution) since editing this
  page only ever needs the id, name, and category already on hand in the
  row — no reason to pull or round-trip the rest of the student record.

## Root Cause
`Inclusivity.tsx` was built with a create-only dialog and never wired an
edit action into its table, even though the shared `EditStudentDialog`
already supported editing this exact field correctly.

## Prevention / Rule
**Guardrail:** None added — this was a missing UI control, not a class of
bug with a mechanical guardrail (e.g. a lint rule can't catch "a feature a
page should expose"). Mitigated instead by matching the existing pattern
(permission-gated edit action + shared dialog) already used on the
Students page, so future per-category pages follow the same template.

## Solution

### Immediate Fix
`inst/src/pages/Inclusivity.tsx`:
- Added an "Actions" column to the table with a permission-gated
  (`student.edit`) edit button per row.
- On click, opens a new, purpose-built `EditInclusivityCategoryDialog`
  (`inst/src/components/EditInclusivityCategoryDialog.tsx`) seeded directly
  from the row's existing `id`/`full_name`/`inclusivity_category` — no
  extra fetch of the full student record.
- The dialog PATCHes only `inclusivity_category` via the existing
  `updateStudent(id, { supportProfiles: { inclusivity } })` partial-update
  path (confirmed the backend serializer/service handle a partial update
  containing just this field).
- `DISABILITY_OPTIONS` was exported from `EditStudentDialog.tsx` so the new
  dialog reuses the same category list instead of duplicating it.
- `onSuccess` closes the dialog and re-fetches the inclusivity list so the
  table reflects the change immediately.

### Long-term Fix
None needed — new dialog is intentionally minimal and reuses the existing
write path and option list.

## Prevention
- [x] UI gap closed (edit action added)
- [ ] N/A — no config/monitoring/doc follow-ups

## Related Issues
- None

## References
- `inst/src/pages/Inclusivity.tsx`
- `inst/src/components/EditInclusivityCategoryDialog.tsx`
- `inst/src/components/EditStudentDialog.tsx`
- `backend/academic/serializers/student_serializers.py`
- `backend/academic/services/student_services.py`

---

**Resolved By:** Claude (Sonnet 5), requested by Tinotenda Mupezeni
**Time to Resolution:** Same session
