# Legacy Per-Board Subject Code Uniqueness Blocked Real ZIMSEC Primary Codes

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging only (production intentionally left untouched)
**Severity:** Medium (blocked a real, intended workflow; not user-facing
breakage)
**Status:** Resolved — verified live on staging

## Summary
While backfilling missing Grade 1-6 offerings for HBEC's six core
primary subjects (so each is offered at every primary grade, reusing the
subject's existing bare ZIMSEC code — e.g. English Language is `701` at
every grade, not a per-grade variant), every attempt to reuse a
primary subject's code at a second grade failed with `400 This code is
already used by another subject in this exam board.`

## Root Cause
`Subject.Meta` carried an old `unique_together = [("exam_board", "code")]`
— one code per subject per board, board-wide, with no grade dimension.
That was true by construction for secondary subjects, where each form's
code is deliberately suffixed (`4005-1`, `4005-2`, `4005-3`, `4005` for
English Forms 1-4) — but false for primary, where ZIMSEC's real Grade
1-7 codes (`701`-`707`) are one bare code meant to be shared across the
entire band. The constraint was already flagged in its own code comment
as "legacy... kept alongside the two real constraints below to avoid
breaking existing rows" — i.e. known to be superseded, just never
removed. The newer `uniq_subject_examboard_grade_code` (unique per
exam-board+grade+code) already prevents a genuine duplicate; the legacy
one was strictly redundant for secondary and actively wrong for primary.

## Solution
`ADMIN/adminBackend/apps/curriculum/models.py` — removed the legacy
`unique_together`, migration `0012_drop_legacy_subject_code_unique.py`.
Cleaned up the now-dead `subjects_exam_board_id_code` branch in
`_subject_integrity_error_response` (`views.py`) — that constraint name
can no longer appear in an `IntegrityError`.

2 new/updated tests: `test_models.py`'s
`test_unique_together_exam_board_code` (previously asserted the now-wrong
behavior) replaced with `test_same_code_reusable_across_grades` (the new,
correct behavior) and `test_unique_together_family_grade` (confirms the
real duplicate-prevention constraint still works); `test_subject_create_api.py`
gained `test_same_code_at_a_different_grade_is_allowed`, an API-level
regression guard for the exact bug. Full `apps/curriculum` suite (99
tests, up from 97) passes.

## Real-data cleanup done in the same pass
While researching this (per a related request to make primary subjects
default to every grade — see the two entries above), also found and
fixed two duplicate `SubjectFamily` rows on staging's "Heritage Based
Curriculum Assistant" board, both wording drift: "Physical Education &
Arts" (Grade 3, code `7130`, clearly a typo/legacy code) vs "Physical
Education and Arts" (Grade 7, code `707`, the real ZIMSEC code); and
"Indigenous Language (Shona/Ndebele)" (Grade 7, `703`) vs "Indigenous
Language(Shona/Ndebele)" (Grade 6, `703-6`, missing a space and a
suffixed code that shouldn't have needed one). Merged each pair (the
minority grade's `Subject` row re-pointed to the canonical family, code
corrected to match), then backfilled Grade 1-6 for all six core primary
subjects (Agriculture/Science/Technology-705, English Language-701,
Indigenous Language-703, Mathematics-702, Physical Education and
Arts-707, Social Sciences-706) — 34 new `Subject` rows created via the
real `POST /api/curriculum/subjects/` endpoint (not raw ORM), so
replication queued exactly as it would via the admin UI. Verified: each
of the six subjects now shows all of Grade 1 through Grade 7; board's
total family count dropped from 55 to 53 (the two merges).

**Note on scope**: this same naming-drift pattern (e.g. "Musical
Art"/"Musical Arts", three variants of "Physical Education, Sport(s)
and/& Mass Displays (PESMD)", "Family and Religious Studies"/"...（FRS)")
exists much more broadly across this board's *secondary* subjects too —
not touched here, since it wasn't part of what was asked and secondary
offerings are a materially bigger cleanup (more families, more
grades/forms, no single clear canonical-name signal the way the primary
pair's ZIMSEC codes gave one). Worth a dedicated pass if it becomes a
real problem.

## Deployment
Staging only, per explicit instruction — production untouched (confirmed
via image inspection: still running the prior commit's build). Full
staging host health sweep clean after deploy and after the data
migration/backfill.

## References
- `ADMIN/adminBackend/apps/curriculum/models.py` — `Subject.Meta`
- `ADMIN/adminBackend/apps/curriculum/migrations/0012_drop_legacy_subject_code_unique.py`
- `ADMIN/adminBackend/apps/curriculum/views.py` — `_subject_integrity_error_response`
- Related: `HBEC-2026-09-14-primary-subjects-default-to-every-grade.md`
  (the feature this backfill was needed for)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — found mid-execution of the
primary-grade backfill, confirmed with the user before making the
schema change, implemented, tested, deployed to staging only
