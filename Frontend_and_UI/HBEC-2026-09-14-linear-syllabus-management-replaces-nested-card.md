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

## Update (same day): two UX gaps found once live

After shipping, testing the modal against a real subject with an existing
syllabus surfaced a real gap: a grade already covered by an existing
syllabus could still be checked in the upload section — checking it and
uploading would silently archive the current document (the backend
already does this on purpose, see `test_reupload_archives_all_linked_grades_not_just_one`
in `test_subject_syllabus.py`), but the UI gave no indication a replace
was about to happen. Fixed: grades already covered are now disabled in
the checklist with an explanatory note ("already has a syllabus, remove
it above to replace") — replacing one now requires an explicit Remove
first, not an accidental re-check of the same box.

Second gap: the modal only ever listed grades the family was *already*
offered at (`offerings`, passed in from the page). Attaching a syllabus
to a grade the family isn't offered at yet required leaving the modal,
adding the grade offering elsewhere (`AddGradeOfferingButton`), then
coming back. Added an "Offer at a new grade" section listing every
not-yet-offered grade with a code input (mirrors
`AddGradeOfferingButton`'s exact checkbox+code pattern) — checking one
creates that grade offering (`useCreateSubject`) as part of the same
upload, using the newly-created subject's id.

5 new tests cover both: a covered grade's checkbox is disabled with the
note, clicking a disabled checkbox has no effect on upload, an uncovered
sibling grade stays checkable when another grade on the same syllabus is
covered, a new grade offering is created and its id used for the upload,
and an empty code on a new grade blocks the upload. Full suite (123
tests) passes; verified live on staging then production the same
session.

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
