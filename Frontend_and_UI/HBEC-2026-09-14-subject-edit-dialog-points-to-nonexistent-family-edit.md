# Subject edit dialog tells admins to edit family name/description "from the Subjects list" — no such control exists there

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging only (production intentionally left untouched)
**Severity:** Low
**Status:** Resolved — verified live on staging

**Update:** the UI trigger built for this was itself silently
non-functional end-to-end until a separate fix — see
`HBEC-2026-09-14-subject-family-rename-never-replicated-to-students.md`.
A rename saved correctly to the admin DB but never reached the student
backend, since nothing replicated a `SubjectFamily`-only change (only
`Subject.post_save` triggered replication, and no `Subject` row is
touched by a family rename). Fixed the same day, later in the session.

## Summary
`SubjectForm.tsx`'s edit-mode branch (when the `subject` prop is set) renders
the family name as a disabled `<Input>` with a caption telling the admin to
"edit its name/description from the Subjects list" (`/subjects`,
`SubjectFamilyListPage.tsx`). That page has no such capability: clicking a
family's name there opens `SyllabusManagementModal`, not an edit-family form,
and there is no edit button/icon anywhere in the table for a `SubjectFamily`'s
`name`/`description`. The backend (`SubjectFamilyDetailView` +
`SubjectFamilyWriteSerializer`, supports PATCH/PUT on
`name`/`nameSn`/`nameNd`/`description`/`isActive`) and even a frontend API
function (`updateSubjectFamily` in `curriculumApi.ts`) and React Query hook
(`useUpdateSubjectFamily` in `hooks/index.ts`) all exist and are wired
correctly — but nothing in the UI ever calls the hook. The whole edit path is
built and functional except the one thing an admin actually needs: a button.

## Symptoms
- An admin who reads the caption in the "Edit Subject" dialog and goes to
  `/subjects` to rename a subject family finds nothing to click.
- No error, no crash — a comment describing a feature that was never wired up
  to any trigger in the UI.

## Environment Details
- **Files:**
  - `ADMIN/adminFrontend/src/features/curriculum/components/SubjectForm.tsx`
    (~line 230-237: the disabled `<Input value={subject.name} disabled />`
    and the "edit its name/description from the Subjects list" caption)
  - `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectFamilyListPage.tsx`
    (the `/subjects` table — family name `<button>` opens
    `SyllabusManagementModal`, not an edit form; no edit affordance exists)
  - `ADMIN/adminFrontend/src/features/curriculum/api/curriculumApi.ts:44-49`
    (`updateSubjectFamily` — implemented, unused by any UI component)
  - `ADMIN/adminFrontend/src/features/curriculum/hooks/index.ts:174`
    (`useUpdateSubjectFamily` — implemented, no importers outside this file)
  - `ADMIN/adminBackend/apps/curriculum/views.py:144-165`
    (`SubjectFamilyDetailView.update` — fully functional PATCH/PUT)
  - `ADMIN/adminBackend/apps/curriculum/serializers.py:109-120`
    (`SubjectFamilyWriteSerializer` — accepts `name`, `nameSn`, `nameNd`,
    `description`, `isActive`, `examBoardId`; case-insensitive
    per-exam-board uniqueness re-validated on update)

## Investigation Steps

### 1. Initial Diagnosis
Asked to research whether any UI exists to edit a `SubjectFamily`'s
name/description, since `SubjectForm.tsx`'s edit-mode caption claims one does.

### 2. Root Cause Analysis
- Read `SubjectFamilyListPage.tsx` in full: the family-name cell's `<button>`
  `onClick` sets `syllabusFamilyId`, opening `SyllabusManagementModal` — a
  syllabus manager, not a rename form. No other control in the row touches
  `name`/`description`.
- Grepped the whole frontend for `useUpdateSubjectFamily` — the only match
  outside its own definition in `hooks/index.ts` is the import line in the
  same file; no page or component calls it.
- Confirmed the backend and the `updateSubjectFamily()` API wrapper both work
  correctly end-to-end (serializer validation, uniqueness check, `PATCH`
  route) — this is a missing UI trigger, not a broken backend.

### 3. Key Findings
- The caption in `SubjectForm.tsx` was true at some point in intent (the
  hook/API were built for exactly this) but the UI trigger for it was never
  added to `/subjects`, leaving the caption pointing at a feature that
  doesn't exist from an admin's perspective.
- Backend, API client, and hook are all present and correct — only the
  button/modal is missing.

## Root Cause
A family-rename feature was scaffolded end-to-end (model → serializer → view
→ API client → hook) but the UI affordance on `/subjects` that was supposed
to call it was never built, and the caption in the unrelated `SubjectForm`
dialog was written as if it already had been.

## Prevention / Rule
**Guardrail:** An eslint rule (or a small custom lint script) that flags an
exported hook with zero non-definition importers in the feature it belongs
to — `useUpdateSubjectFamily` would have shown up as dead/unreferenced code
the moment it was added, before a caption referencing its (nonexistent)
UI trigger could ship.

This catches exactly this shape of bug: a fully-wired data-layer hook with no
caller, which is what let a UI caption describe a feature that was never
actually reachable.

## Solution

### Immediate Fix
Added `EditSubjectFamilyDialog.tsx` — a small rename dialog (name +
description) using the pre-existing `useUpdateSubjectFamily` hook.
Reached via a pencil icon next to each subject name on `/subjects`
(`SubjectFamilyListPage.tsx`, visible on row hover), leaving the
existing family-name button's own click target (open
`SyllabusManagementModal`) unchanged. `SubjectForm.tsx`'s caption is now
accurate rather than stale.

3 new tests (`EditSubjectFamilyDialog.test.tsx`): pre-fills the current
name/description, saves an edit and calls the mutation with the right
id/payload, rejects a too-short name without calling the mutation.

Verified live: staging's built bundle contains "Edit Subject"; a real
end-to-end `PATCH /api/curriculum/subject-families/{id}/` against a
disposable test family on staging renamed it and updated its
description correctly, then was cleaned up.

### Long-term Fix
None needed beyond the guardrail above.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [x] Code changes required — done, plus 3 new regression tests

## Related Issues
- Found while researching a "bulk-assign a primary subject to all primary
  grades at once" feature design for HBEC's admin curriculum UI (same
  `/subjects` page).

## References
- `ADMIN/adminFrontend/src/features/curriculum/components/SubjectForm.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectFamilyListPage.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/api/curriculumApi.ts`
- `ADMIN/adminFrontend/src/features/curriculum/hooks/index.ts`
- `ADMIN/adminBackend/apps/curriculum/views.py`
- `ADMIN/adminBackend/apps/curriculum/serializers.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery — verified live on
staging (production intentionally left untouched, per explicit
instruction)
