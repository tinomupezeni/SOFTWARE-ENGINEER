# Syllabus Management Moved to /subjects, Replacing the Nested Per-Grade Card

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production
**Severity:** N/A (feature, not a bug)
**Status:** Resolved — verified live on staging and production

## Summary
Requested feature: syllabus management was buried inside the per-grade
`SubjectPage` (a 2-3 click drill-down: Board → Grade → Subject) as one
card (`SyllabusCard.tsx`) among many other concerns, and only ever showed
one grade's view of a syllabus at a time — no way to see, from one place,
which syllabus documents exist for a subject identity and which grades
each covers. Moved onto the existing subject-first `/subjects` page:
clicking a subject now opens a modal listing every syllabus document for
that subject family, each showing which grades it covers, with an upload
flow that attaches one document to several grades at once. The old
per-grade card is removed entirely.

## What changed

### Backend (`ADMIN/adminBackend/apps/curriculum/`)
- New `GET /curriculum/syllabuses/?examBoardId=` (`SyllabusListView` +
  `SyllabusReadSerializer`) — lists every published syllabus for a board
  with the `Subject` (grade-offering) ids it covers. Nothing existed
  before that could answer "every syllabus for a family" — the only prior
  read path (`SubjectSyllabusView.GET`) only ever answered for one
  subject at a time.
- No changes to upload/remove — the existing `SubjectSyllabusView`
  `POST`/`DELETE` already did exactly what the new modal needs (one
  anchor subject id + repeated sibling ids; shared-archive on delete), so
  the frontend just calls them with the right ids.

### Frontend (`ADMIN/adminFrontend/src/features/curriculum/`)
- New `SyllabusManagementModal.tsx`, reached by clicking a subject row on
  `/subjects` (`SubjectFamilyListPage.tsx`) — lists existing syllabuses
  with the grades each covers, an upload dropzone with a grade checklist,
  and remove.
- `SubjectFamilyListPage.tsx` gains a "Syllabus" table column (e.g. "2
  syllabuses — Form 1-4, Form 5-6" or "No syllabus").
- Deleted `SyllabusCard.tsx` and its mount point on `SubjectPage.tsx`
  entirely.
- Repurposed the subject-id-bound `useUploadSubjectSyllabus`/
  `useRemoveSubjectSyllabus` hooks into call-time-parameterized
  `useUploadSyllabus`/`useRemoveSyllabus` (the modal manages many
  grade/subject combinations at once, so the target id can't be bound at
  hook-construction time the way the old one-card-per-grade design
  needed).

## Related inconsistency fixed along the way
`createSubject()`'s Add Subject dialog has an optional "attach a syllabus
at creation time" file field. It used to upload that file through the
generic content pipeline (`createContent()`) directly, bypassing the real
`Syllabus` model and sibling-grade linking entirely — so a subject
created with a file attached wouldn't show up correctly in the new
syllabus column or modal. Now goes through the same
`uploadSubjectSyllabus()` path as every other syllabus upload.

## Testing
- Backend: 5 new tests (`test_syllabus_list.py`) — scoped to the
  requested board, doesn't leak another board's syllabus in, includes
  every linked subject id, empty-list case, archived syllabuses excluded.
  Full `apps/curriculum` suite (97 tests) passes.
- Frontend: 6 new tests (`SyllabusManagementModal.test.tsx`) — empty
  state, lists an existing syllabus with its covered grades, excludes a
  different family's syllabus, uploads with the first checked grade as
  anchor and the rest as siblings, refuses to upload with nothing
  checked, removes using any one of the linked subject ids. Full suite
  (118 tests, up from 112) passes. `typecheck`/`eslint` clean.
- Live verification, both staging and production: uploaded a real
  syllabus covering two real grades of an existing subject family via
  the actual API path the modal uses, confirmed the new list endpoint
  showed both subject ids correctly, confirmed the built frontend bundle
  no longer contains any string from the deleted `SyllabusCard` and does
  contain the new modal's copy, deleted it via one of the two linked
  subject ids and confirmed it disappeared from the list (shared-archive
  behavior intact). Full host health sweep clean on both environments
  after deploy.

## References
- `ADMIN/adminBackend/apps/curriculum/views.py` — `SyllabusListView`
- `ADMIN/adminBackend/apps/curriculum/serializers.py` — `SyllabusReadSerializer`
- `ADMIN/adminFrontend/src/features/curriculum/components/SyllabusManagementModal.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectFamilyListPage.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/api/curriculumApi.ts` —
  `getSyllabuses`, `createSubject`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — planned, implemented, tested, and
promoted to production in one pass
