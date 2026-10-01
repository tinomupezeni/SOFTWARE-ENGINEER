# Subject Duplication Fix Deployed to Production; Data Cleanup Executed

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Deployment + production data cleanup (follow-on to same-day investigation)
**Status:** Completed — verified against real production data, including the originally-reporting tester's account

## Context / Trigger
Direct continuation of
`reports/HBEC-2026-10-01-subject-duplication-prevention-and-admin-visibility.md`,
which deliberately stopped short of deploying or touching any data, per
explicit user instruction to fix the code first and do cleanup last. User
then explicitly asked to deploy and proceed with the cleanup.

## Scope
Staging → production promotion of the subject-duplication fix (3 follow-up
commits beyond the original fix, each caught live by actually exercising the
new code against real data rather than assuming it worked), followed by
running the new data-cleanup command against production.

## Method
Deployed via the manual runbook path (`docs/STAGING_TO_PRODUCTION_RUNBOOK.md`)
since GitHub Actions failed at its known `./staging.sh`-missing step (a
pre-existing, already-documented infra gap, unrelated to this change — the
images it built were used directly). Every fix in this report was found by
actually running the new code against real staging/production data, not by
code review alone — each would have shipped a real bug to production without
that step.

## Decisions & Findings
- **CI's lint step blocked a fully green pipeline** on repo-wide drift
  (an unpinned `ruff` picked up new rules in files unrelated to this change).
  Fixed mechanically — cheap, zero-behavior-change, and left CI red otherwise.
- **A hardcoded exam-board code (`"ZIM-HBCA"`, copied from the existing
  `merge_legacy_subjects.py`) silently matched zero rows on production.**
  The same exam board row (identical UUID) carries `code="ZIM-HBCA"` on
  staging and `code="ZIMSEC-HBCA"` on production — real drift in a
  supposedly-replicated field between environments. The dry-run against
  staging looked completely correct and would have shipped a no-op against
  production with no error at all. Fixed by matching retired/canonical
  subjects by shared `exam_board_id`, not a hardcoded code string — the
  actual safety property needed (never merge across boards) without the
  fragility.
- **A real-data collision the staging dry-run didn't fully exercise, until
  `--apply` was actually run there first.** `Topic` has a genuine
  `(release, subject, code)` uniqueness constraint, and a canonical subject
  can already carry its own topic at the same `(release, code)` — both sides
  were authored somewhat independently while the underlying bug was live. A
  blind bulk move hit this and aborted the entire command; confirmed the
  outer transaction rolled back cleanly (no corruption) before fixing it.
  Fixed: topics move one at a time under their own savepoint; a collision
  skips only that one topic, leaving it exactly where it is — never deleted,
  per the standing "never delete" instruction for this cleanup.
- **The production impact was far larger than the one reported tester.**
  Dry-run against real production data found 19 stalled subjects, 35
  stranded topics + 4 papers, and **161 real student profiles** still
  referencing retired codes — meaning the existing `fix_duplicate_subjects.py`
  had never fully run (or ran incompletely) against production. Reported
  this scale to the user explicitly before running `--apply`, rather than
  proceeding on the earlier general go-ahead alone, given the gap between
  "one tester" and "161 real accounts."
- **7 orphans remain, deliberately not touched.** All fall outside the
  already-audited `(retired_code, canonical_code)` pairs list — several are
  the same legacy-named codes (`MATH_O`, `SCI_O`) that
  `merge_legacy_subjects.py`'s own docstring already flagged as needing
  human product judgment rather than automated guessing. Left for a
  separate, deliberate follow-up.

## Changes Made
- Promoted `HBEC` production from `dea79aee` to `ac564bfa` (retagged,
  digest-verified staging images — no rebuild on production, per standing
  discipline).
- Ran `reconcile_stalled_subject_merges --apply` against production
  `hbec_student`: 19 subjects reconciled, 27 topics + 4 papers moved
  (8 topics intentionally left in place on one pair due to a content
  collision), 161 student profiles remapped, 19 retired subjects
  deactivated (`is_active=False`) — **zero rows deleted**, per explicit
  product decision carried through this entire initiative.
- `/opt/hbec/.last_good_sha` → `ac564bfa`; `.PROMOTION_NOTES.txt` updated;
  `main` fast-forwarded to match `master`.

## Verification
- `verify-service-links.sh` and `check_runtime_secret_drift.py` clean
  post-deploy; full production container health sweep clean.
- Direct DB query: the originally-reporting tester's History subject
  (code `6006`) now carries real content (9 topics, 1 paper) moved off its
  orphan (`6006 -5`, now deactivated with 0/0); confirmed via
  `TopicListView`-equivalent query that real topic titles ("Paper 1: History
  of Zimbabwe", etc.) are now attached and live.
- Admin's new reconciliation panel confirmed the orphan-with-real-content
  count dropped from 64 (initial discovery) to 7 (all deliberately deferred,
  see Decisions & Findings).
- Dry-run and `--apply` both run first on staging before ever touching
  production, at every iteration of the three live-caught fixes above.

## Follow-ups / Deferred
- 7 remaining orphans need a separate, deliberate product decision
  (which admin subject a student "really meant") before any action —
  explicitly not guessed at here, matching the discipline already
  established by `merge_legacy_subjects.py`.
- The one topic-collision case (`6022-5`, 8 topics left in place) could be
  revisited manually if those topics turn out to contain content worth
  reviewing against what's already under `6022`.
- Consider pinning `ruff`'s version in CI (currently installed unpinned)
  to stop future drift from silently blocking the lint step — flagged, not
  fixed, in this report.

## References
- `reports/HBEC-2026-10-01-subject-duplication-prevention-and-admin-visibility.md`
  (the code-only phase this report completes)
- `Backend_and_API/HBEC-2026-10-01-topic-paper-additions-never-busted-subjects-cache.md`
  (the original, separate production incident that led to this investigation)

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session
