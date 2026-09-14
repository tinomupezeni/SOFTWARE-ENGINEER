# Add Grades to an Already-Uploaded Syllabus Without Re-Uploading

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging only (production intentionally left untouched)
**Severity:** N/A (feature, not a bug)
**Status:** Resolved — verified live on staging

## Summary
Requested: if a syllabus document already covers some grades and an
admin wants to add more, they should just be able to select the
additional grades and save — not re-upload the same file again.

Before this, the syllabus-management modal's only way to change which
grades a document covered was the "Upload a syllabus" section, which
requires a real file on every request (`SubjectSyllabusView.POST`
`400`s without one). Extending "the syllabus that already covers Grade
7" to also cover Grade 1-6 meant re-selecting the exact same PDF from
disk each time.

## Solution

### Backend
New `POST /curriculum/syllabuses/{id}/grades/` (`SyllabusAddGradesView`)
— adds `Subject` rows to an existing `Syllabus`'s M2M in place (`.add()`,
not `.set()` — doesn't disturb grades already covered), reusing the
syllabus's own already-stored file: re-probes it for text (same
`extract_document_text()` call the original upload makes) and fans out
one new `Content` row per newly-added grade only, leaving the rows for
already-covered grades untouched. Guards: rejects subjects already
covered, subjects from a different exam board, and an empty request.

A newly-added grade that happens to already have some *other* unrelated
syllabus gets that one archived first, the same way a fresh upload
would — a defensive guard, since the frontend's own checklist already
disables that case, but a stale request shouldn't be able to leave two
active syllabuses on the same grade.

**A real bug caught before it shipped**: the first implementation called
`syllabus.file.seek(0)` before assigning it to each new `Content` row's
`file` field, mirroring the original upload endpoint's loop — but that
loop re-reads a fresh, not-yet-committed `UploadedFile` each iteration,
which genuinely needs seeking; here, `extract_document_text()` had
already closed the file (called once, just above), and `syllabus.file`
was already a *committed* `FieldFile` — assigning it to another model's
`FileField` just copies the storage path, no read needed at all. Fixed
by removing the seek — the assignment was never reading the file's bytes
in the first place, so every new `Content` row for the same syllabus
now correctly shares its one stored file rather than needing (or
failing) a duplicate read.

### Frontend
Each existing syllabus entry in `SyllabusManagementModal.tsx` gained an
"Add grades" popover (mirrors `AddGradeOfferingButton`'s pattern) —
lists every offering not yet covered by *that* document; a grade covered
by a *different* syllabus is disabled with the same "already has a
syllabus, remove it above to replace" note used in the main upload
section, so extending one document can never silently double up with
another.

## Testing
7 new backend tests (`test_syllabus_add_grades.py`): adds a grade
without a file, adds several at once, rejects an already-covered grade,
rejects an empty request, 404s for an unknown syllabus, ignores a
subject from a different board, response includes the updated subject
id set. Full `apps/curriculum` suite (106 tests, up from 99) passes.

3 new frontend tests: adds grades via the popover with no new file
upload involved, the "Add grades" control doesn't render once a
syllabus already covers every offering, a grade covered by a different
syllabus is disabled in the picker. Full suite (140 tests, up from 137)
passes; `typecheck`/`eslint` clean.

## Deployment
Staging only, per explicit instruction — production untouched (confirmed
via image inspection: still running the prior commit's build). Verified
live on a real syllabus: "Junior Indigenous Languages Syllabus (Grade
7)" extended to also cover Grade 1 with no file re-upload, replication
queued correctly. Left in place rather than reverted — a real syllabus
now genuinely covering more of the grades it was created for is a
correct outcome, not test residue. Full staging host health sweep clean
after deploy.

## References
- `ADMIN/adminBackend/apps/curriculum/views.py` — `SyllabusAddGradesView`
- `ADMIN/adminFrontend/src/features/curriculum/components/SyllabusManagementModal.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/hooks/index.ts` — `useAddSyllabusGrades`
- Related: `HBEC-2026-09-14-linear-syllabus-management-replaces-nested-card.md`
  (the modal this extends)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — implemented, caught and fixed a
real bug (stale file-handle seek) during testing, deployed to staging
only, verified live against a real syllabus
