# Phase 10.1 — Critical Artistic Regression Fix

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Type:** Regression fix / architecture correction
**Status:** Completed

## Summary
Phase 10's duration-aware stroke budget reduced tonal shading detail for
short playback sessions (as low as 13.8% of hatch strokes retained at 2
minutes), producing a measurably and visibly sparser finished drawing
than longer sessions despite the UI reporting "100% complete." The user
made an explicit, overriding product decision: drawing duration must
control only playback pacing, never artwork completeness. The
stroke-budget mechanism was removed entirely and replaced with a
presentation-only pacing classification; verified that stroke count is
now identical (26,042 for the skull benchmark) across the full
2-minute-to-4-hour range, with a bounded, documented pixel-level
difference between the shortest and longest sessions' final renders.

## Context / Trigger
Direct user regression report, with before/after screenshots described
(an earlier, properly-shaded skull vs. the current sparse, near-outline
result at reported 100% completion), and an explicit architectural
mandate: "DRAWING DURATION MUST NOT CONTROL FINAL ARTWORK COMPLETENESS."

## Scope
**Included:** `backend/planner.py` (removing the stroke budget, adding
pacing classification), full backend/frontend regression-test coverage
for the corrected invariant, real-browser before/after/corrected
screenshots, a controlled temporary reproduction of the old defect for
evidence purposes.

**Excluded, per explicit instruction:** no UI redesign, no new rendering
styles, no ML models, no unrelated refactoring. The Phase 9 artistic
pipeline (color preservation, multi-scale contours, background
suppression) was not touched and reconfirmed working via the same
screenshots used to verify this fix.

## Method
Verify before changing anything: there is no git history in this
repository (never committed), so the investigation reconstructed what
Phase 10 had added from the session's own record, then measured the
actual stroke-retention numbers across the UI's full duration range
directly against the live pipeline (not assumed). Confirmed the
regression was real and specifically localized (2-10 minute range; the
originally-reported 2hr/4hr sparseness was not reproduced -- those
durations were already at `detailBudgetFraction: 1.0`, i.e. unaffected,
a finding worth separating from the confirmed defect rather than
conflating the two). Captured a genuine "broken" screenshot by
temporarily and explicitly reintroducing the removed code behind an
environment-variable flag, then immediately restored the fix and
reran the full test suite to confirm no residual effect.

## Decisions & Findings

### Root cause
`select_stroke_budget` (Phase 10) stratified-sampled the non-essential
(hatch) stroke pool down to fit a capped acceleration factor for short
sessions, correctly diagnosing that drawing all ~26,000 strokes at
natural pace within 2 minutes requires physically impossible per-stroke
speed, but solving that *pacing* problem by removing *artistic content*
-- the wrong layer entirely. The correct mechanism for pacing already
existed and was untouched: `frontend/js/timeline.js` linearly scales
every action's duration to fit the requested session length, with zero
effect on which actions (and therefore which strokes) exist.

### Architectural correction (the explicit product decision)
Implemented throughout: a plan's `strokes` are always the complete
artistic output, independent of `target_duration_seconds`. That parameter
now only feeds `classify_duration_pacing`, which reports a `pacing`
label (`"natural"` or `"timelapse"`) and an `accelerationFactor` in plan
metadata for the frontend's "Time-lapse" badge -- a pure presentation
signal, never a content decision. Short sessions play back faster than
physically realistic (explicitly accepted per the product decision); long
sessions play back slower; the artwork itself never changes.

### Playback completion verified, not assumed
Confirmed via both a real (non-debug, actual wall-clock) 2-minute
playback and the (now-fixed, see the companion Phase 10 playback-engine
bug log) debug-seek mechanism that `actionCursor` reaches the final
action index at "100%" in both cases, and that the two methods agree --
"100% complete" genuinely means every scheduled draw action executed, not
a premature completion flag.

## Changes Made
- `backend/planner.py` -- removed `select_stroke_budget`,
  `_sample_reducible_strokes`, `_is_always_kept`, and their constants
  (`MAX_BELIEVABLE_SPEED_FACTOR`, `NATURAL_TIME_OVERHEAD_MULTIPLIER`,
  `MIN_DETAIL_BUDGET_FRACTION`, `DETAIL_BUDGET_SEED`); added
  `classify_duration_pacing`; `build_drawing_plan` no longer filters
  strokes based on `target_duration_seconds`.
- `backend/main.py` -- updated docstring to reflect the corrected
  contract (duration affects metadata only).
- `backend/test_planner.py` -- replaced the entire Phase 10 test section
  (which encoded the old, now-wrong, behavior) with 9 tests pinning the
  corrected invariant: identical stroke ids/counts across every duration,
  identical category counts (line/tonal-band/colored), dark-shading
  strokes present at every duration, deterministic pacing classification,
  region coverage, plan-invariant validity, and empty/minimal images with
  a duration specified.
- `frontend/test/timeline.test.js` -- added a test confirming
  `buildTimeline` never drops entries regardless of the requested target
  duration.

## Verification
- **Backend:** 125 tests passed, `pytest -q`.
- **Frontend:** 139 tests passed, `node --test`.
- **Real browser verification:** re-ran the full 5-category x 2-duration
  Playwright suite (skull, synthetic full-color portrait, grayscale
  pencil portrait, landscape, geometric shapes; 2 min and 4 hr each) --
  zero page errors, correct "Time-lapse" badge behavior preserved.
- **Stroke-count parity, measured via the live HTTP endpoint** (not just
  unit tests): all six UI duration options (2/15/30/60/120/240 minutes)
  now return exactly 26,042 strokes for the skull benchmark, where before
  the fix 2 minutes returned 4,729.
- **Pixel-level before/after:** diffed the 2-minute and 4-hour final
  Canvas renders of the same image/style/seed. Mean absolute difference:
  0.17/255. Only 0.24% of pixels differ by more than 10/255, scattered
  across the whole canvas (not concentrated in any region) -- consistent
  with ordinary antialiasing/rounding noise, not missing content. This is
  the "minor numerical differences... document and bound them" case
  explicitly anticipated by the corrected requirement, not a residual
  defect.
- **Controlled regression repro:** temporarily reintroduced the removed
  code behind an environment-variable flag, captured a genuine "broken"
  screenshot showing visibly thinner hat/jacket hatching at 2 minutes,
  then immediately restored the fix and reran the full test suite to
  confirm zero residual effect -- the before/after comparison in this
  report is real, not reconstructed from description.

### Before / after stroke statistics (skull benchmark, all 6 UI options)

| Duration | Before (strokes kept) | After (strokes kept) | Pacing |
|---|---|---|---|
| 2 min | 4,729 / 26,042 (13.8%) | 26,042 / 26,042 (100%) | timelapse |
| 15 min | 26,042 (100%) | 26,042 (100%) | timelapse |
| 30 min | 26,042 (100%) | 26,042 (100%) | natural |
| 60 min | 26,042 (100%) | 26,042 (100%) | natural |
| 120 min | 26,042 (100%) | 26,042 (100%) | natural |
| 240 min | 26,042 (100%) | 26,042 (100%) | natural |

(7-minute and other sub-10-minute points were also affected before the
fix, e.g. 93.3% at 7 minutes -- not just the 2-minute extreme.)

## Follow-ups / Deferred
- The user's initial report also described 2-hour and 4-hour sessions as
  sparse; this was not reproduced (those durations were already at full
  detail both before and after this fix). Flagging this explicitly rather
  than silently dropping it: if the user still observes sparse output at
  long durations after this fix, it is a *different* defect and should be
  investigated separately with its own real-browser evidence, not assumed
  to be covered by this report.
- `classify_duration_pacing`'s `accelerationFactor` is computed from pure
  per-stroke draw time (no travel/pause overhead estimate), a simpler and
  more conservative basis than Phase 10's original formula -- documented
  as a presentation-only heuristic, consistent with the rest of the
  planner's estimates.

## References
- `ATELIER-2026-10-28-duration-aware-stroke-budget-thinned-out-artwork.md`
- `reports/ATELIER-2026-10-28-phase-10-duration-aware-artistic-planning.md` (the original feature this corrects)
- `backend/planner.py`, `backend/test_planner.py`, `frontend/test/timeline.test.js`

---

**Completed By:** Claude (pair-programming session with tinomupezeni)
**Duration:** Single focused session (Phase 10.1, immediately following Phase 10)
