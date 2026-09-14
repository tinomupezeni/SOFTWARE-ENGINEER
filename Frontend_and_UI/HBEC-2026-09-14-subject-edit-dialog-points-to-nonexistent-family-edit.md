# Subject edit dialog tells admins to edit family name/description "from the Subjects list" — no such control exists there

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging + source inspection (found during research for a primary-grade bulk-assignment feature design, not yet checked on production)
**Severity:** Low
**Status:** Investigating (found, not fixed — out of scope; flagged during a research-only task)

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
Not applied — out of scope for the research task this was found during.

### Long-term Fix
Add an edit affordance for `SubjectFamily` on `/subjects` (e.g. a pencil icon
next to the family name opening a small rename/description form that calls
the existing `useUpdateSubjectFamily` hook), or, if that's intentionally
deferred, correct the caption in `SubjectForm.tsx` so it doesn't point admins
at a control that doesn't exist yet.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [x] Code changes required — add the missing edit UI on `/subjects`, or fix the stale caption

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

**Resolved By:** Not resolved — logged only
**Time to Resolution:** N/A
