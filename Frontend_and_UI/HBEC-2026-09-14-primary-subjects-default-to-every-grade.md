# Primary Subjects Now Default to Every Grade When Offered

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging only (production intentionally left untouched)
**Severity:** N/A (feature, not a bug)
**Status:** Resolved — verified live on staging

## Summary
Requested: primary-phase subjects (Grade 1-7) are the same subjects
across every grade in practice — unlike secondary, where offerings
genuinely differ by form. The two places an admin picks which grades to
offer a subject at (Add Subject's multi-grade checklist on `/subjects`,
and the per-row "Add grade" popover) required checking each primary
grade individually every time, even though the answer is almost always
"all of them."

## Research first
Before building anything, checked a related claim from the request:
whether the codebase's "Infant" (ECD-Grade 2) vs "Junior" (Grade 3-7)
syllabus-band split — named in `Syllabus`'s own model docstring
(`ADMIN/adminBackend/apps/curriculum/models.py`) — actually exists in
real data. **It doesn't**: no Grade 0-2 exists anywhere in the system
today (only Grade 1-7 are real `Grade` rows), and none of the 7 real
primary-phase `Syllabus` rows on staging span more than one grade,
despite several being titled "Junior [Subject] Syllabus." That split is
aspirational documentation, not implemented reality. Decision: treat all
primary grades uniformly for this default rather than building UI for a
band distinction the data doesn't have yet — the existing
syllabus-management modal (see the linear-syllabus-management entry from
earlier today) already lets an admin pick any subset of grades per
document whenever two genuinely separate documents exist for real.

## Solution
`AddGradeOfferingButton.tsx` and `SubjectForm.tsx`'s multi-grade create
path both pre-check every primary-phase grade in their respective
available-grades list as soon as the picker opens (a `useEffect` guarded
by `Object.keys(prev).length === 0`, keyed on the dialog/popover's own
`open` state rather than the grades list itself, so re-renders while
already open don't clobber an admin's in-progress unchecks). Still just
a default: any grade — primary or not — can be unchecked before
submitting, and non-primary grades are never auto-checked.

6 new tests across the two components: pre-checks every primary grade,
leaves a non-primary grade unchecked, and confirms an admin can still
uncheck a pre-checked primary grade before submitting. Full suite (137
tests, up from 129) passes; `typecheck`/`eslint` clean.

## Deployment
Staging only, per explicit instruction — production untouched (confirmed
via image inspection: still running the prior commit's build). Full
staging host health sweep clean after deploy.

## References
- `ADMIN/adminFrontend/src/features/curriculum/components/AddGradeOfferingButton.tsx`
- `ADMIN/adminFrontend/src/features/curriculum/components/SubjectForm.tsx`
- `ADMIN/adminBackend/apps/curriculum/models.py` — `Grade.Phase` (single
  `primary` bucket, confirmed no infant/junior sub-bands exist),
  `Syllabus` docstring (the aspirational band description)
- Related: `HBEC-2026-09-14-subject-edit-dialog-points-to-nonexistent-family-edit.md`
  (the subject-name-editing gap fixed in the same pass)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — researched, implemented, tested,
deployed to staging only
