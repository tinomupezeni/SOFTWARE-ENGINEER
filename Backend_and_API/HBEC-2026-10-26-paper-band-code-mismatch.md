# Form 3/4 and Form 5/6 papers weren't actually shared, for most subjects

**Date:** 2026-10-26
**Project:** HBEC
**Environment:** Production (confirmed via a read-only query against the live DB)
**Severity:** High
**Status:** Resolved

## Summary
ZIMSEC examines once per phase (Form 4, not Form 3; Form 6, not Form 5), so
a past paper authored under one form is supposed to be visible to students
in the sibling form too — a dedicated "paper band" feature
(`apps/curriculum/bands.py::subjects_in_paper_band`) exists specifically for
this. It worked correctly for the data it was designed around, but matched
sibling subjects by their free-text per-grade `code` field — and a live
production query found that field mismatched between Form 3/Form 4 (or Form
5/Form 6) for the majority of real subjects, so the sharing silently never
happened for them.

## Symptoms
- User-reported, from ProjectFlow: "Papers aren't shared" — "Form 6 and 5,
  Form 4 and 3".
- No error, no exception — the feature degrades silently: a student in the
  "wrong" half of a phase simply sees fewer papers than they should, with
  nothing in the UI or logs suggesting anything is missing.

## Environment Details
- **Server/Host:** Student Backend, production (both blue/green colors).
- **Services Affected:** `apps/curriculum/bands.py`, `apps/practice/views.py`
  (paper listing).
- **Related Components:** `ADMIN/adminBackend/apps/curriculum/models.py`
  (`Subject`, `SubjectFamily`) — the data this bug depends on.
- **Time First Observed:** 2026-10-26, reported by the user.

## Investigation Steps

### 1. Initial Diagnosis
Found the band-sharing mechanism (`subjects_in_paper_band()`), read its
docstring and tests, and confirmed it was deliberately designed and tested
for exactly the scenario reported (`test_form_3_reaches_the_o_level_papers`
existed and passed). So the mechanism was correct — the question became
whether its join key (`Subject.code`) actually lines up in real data.

### 2. Root Cause Analysis
Ran a read-only Django ORM query against the live production database
(`hbec-admin-backend-green`, no writes), joining every Form 3 `Subject` row
to its Form 4 sibling (same `SubjectFamily`) and comparing `code`, then the
same for Form 5/Form 6:

```python
from apps.curriculum.models import Subject, Grade
subs1 = {s.family_id: s for s in Subject.objects.filter(grade__code="form-3").select_related("family")}
subs2 = {s.family_id: s for s in Subject.objects.filter(grade__code="form-4").select_related("family")}
# compare s1.code vs s2.code for every shared family_id
```

### 3. Key Findings
- **Form 3 ↔ Form 4: 37 of 66 shared subjects (56%) have mismatched
  `code`.** Near-universal pattern: Form 3's code carries a `-3` suffix the
  Form 4 code lacks (e.g. Geography: `4022-3` vs `4022`).
- **Form 5 ↔ Form 6: 18 of 29 shared subjects (62%) mismatched**, with far
  less consistent patterns — various suffix styles (`-5`, `-6`, ` - 5`,
  `/1`) and some pairs with no obvious relationship at all (Physics: `6032`
  vs `phys`; Statistics: `6046` vs `stats-6`).
- The correct stable identity already exists and is already replicated:
  `Subject.canonical_key`, sourced from `SubjectFamily.canonical_key`
  ("Stable cross-board identity used to match equivalent subjects") at
  replication time (`ADMIN/adminBackend/apps/replication/signals.py:200`,
  `tasks.py:647`). `apps/practice/views.py` already used exactly this field
  for the *cross-board* sharing case (`shared_across_boards`) — the
  within-board band widening (`subjects_in_paper_band`) was the one place
  still keying on `code`.
- User's own framing, once the root cause was explained: the per-grade paper
  `code` is allowed to differ between a subject's Form 3 and Form 4 offering
  (real, independent fact about how the exam board numbers papers) — the fix
  must not touch or unify the `code` values, only the matching key used to
  decide *access*.

## Root Cause
`subjects_in_paper_band()` matched sibling subjects (the ones whose papers a
learner may also sit) on the free-text, per-grade `Subject.code` field,
which is not guaranteed to agree between a subject's offerings at different
grades in the same phase — and, measured in production, usually doesn't.
The subject's real stable identity (`canonical_key`, shared across all of a
`SubjectFamily`'s per-grade `Subject` rows) already existed and was already
used for the sibling cross-board-sharing feature, but not for this one.

## Prevention / Rule
**Guardrail:** Any code matching "is this the same subject" across grade or
board boundaries must use `canonical_key` (falling back to `code` only when
`canonical_key` is blank), never `code` alone — `code` is free text scoped
to one specific grade's offering and is not a subject-identity field. This
was already the convention for the cross-board sharing path; it is now the
convention everywhere subject identity is compared within this feature
family.

This closes the specific gap because `canonical_key` is populated once per
`SubjectFamily` (authored by the admin as the subject's identity, separate
from the per-grade offering) and replicated unchanged onto every grade's
`Subject` row — it cannot drift between Form 3 and Form 4 the way a
hand-typed per-grade code can.

## Solution

### Immediate Fix
`apps/curriculum/bands.py::subjects_in_paper_band()`: match on
`canonical_key` when the subject has one, falling back to the old `code`
match when it's blank (so a subject with no family link, or on a board that
doesn't curate one, isn't wrongly unioned with every other blank-key
subject in the band). `exam_board_id` still pins the match to one board in
both branches. 4 new tests cover: the actual production mismatch scenario
(mismatched code, matching canonical_key, now correctly reunited), that a
blank canonical_key never unions unrelated blank-key subjects, and that the
canonical_key match still respects the exam-board boundary.

### Long-term Fix
None needed on the matching logic — `canonical_key` is exactly the right
join key and already exists. The remaining risk is upstream: nothing stops
an admin from leaving two sibling subjects' `canonical_key` blank or
inconsistent when authoring a new one by hand. Worth a future pass checking
whether the admin UI should default/validate `canonical_key` to match a
sibling grade's value within the same family — deferred, since the common
case (seeded ZIMSEC data) already carries it correctly and this was not the
reported symptom.

## Prevention
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — none identified; this failure mode is
      silent by nature (fewer papers shown, no error), so an alert would
      need its own design (e.g. a scheduled audit comparing `code` vs
      `canonical_key` symmetry across sibling grades) — not built here.
- [ ] Documentation to update — none beyond the docstring updated in place.
- [x] Code changes required — done, see Solution.

## Related Issues
- None directly; this sits beside the cross-board `shared_with_subjects`
  feature (`CLAUDE.md` "Sharing a paper with another exam board"), which
  already used `canonical_key` correctly and was not affected.

## References
- `STUDENT/hbec_backend/apps/curriculum/bands.py`
  (`subjects_in_paper_band`)
- `STUDENT/hbec_backend/apps/curriculum/tests/test_bands.py`
- `STUDENT/hbec_backend/apps/practice/views.py` (comments updated to match)
- `ADMIN/adminBackend/apps/curriculum/models.py` (`Subject`,
  `SubjectFamily.canonical_key`)
- `ADMIN/adminBackend/apps/replication/signals.py:200`,
  `apps/replication/tasks.py:647` (where `canonical_key` is replicated)
- Pre-existing, unrelated test failures noticed during verification (not
  caused by this fix, confirmed identical on master before this change):
  `apps/practice/tests/test_paper_sharing_explicit.py::TestChosenSubjects::
  test_global_flag_reaches_equivalent_subject_without_target_rows` and
  `::test_a_paper_with_chosen_subjects_reaches_no_other_subject` — root
  cause not investigated (out of scope), but the failure shape suggests a
  test-fixture subject's `grade_code` is set to a band name (`"a-level"`)
  rather than a real form code, which `grades_in_paper_band()` would never
  match. Worth a separate look.

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** Same session as reported
