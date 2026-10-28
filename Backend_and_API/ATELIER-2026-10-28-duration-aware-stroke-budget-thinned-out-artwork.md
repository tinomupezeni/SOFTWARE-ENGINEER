# Duration-aware stroke budget silently thinned out finished artwork

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Environment:** Development
**Severity:** Critical
**Status:** Resolved

## Summary
Phase 10's `planner.select_stroke_budget` reduced the number of hatch
(tonal shading) strokes retained for short playback durations -- at a
2-minute session, only 13.8% of the skull benchmark's hatch strokes
survived planning. The completed drawing at "100%" was therefore
measurably and visibly sparser (thinner graphite buildup, lighter
suit/hat shading) than the same image at a longer duration, even though
the UI reported the drawing as complete. This coupled a pure presentation
choice (how fast the user wants to watch the drawing happen) to the
artwork's actual content, which is an architectural mistake, not a tuning
problem -- the feature was removed and replaced with a presentation-only
pacing classification.

## Symptoms
- A completed ("100%") 2-minute session's skull drawing showed visibly
  thinner hatching on the hat and jacket than the same image played over
  a longer duration, despite the UI reporting full completion.
- Measured: 4,729 of 26,042 strokes kept at 2 minutes (`detailBudgetFraction: 0.138`)
  vs. all 26,042 at 10+ minutes.

## Environment Details
- **Server/Host:** local dev (`uvicorn` on 127.0.0.1:8787)
- **Services Affected:** `backend/planner.py` (`build_drawing_plan`),
  consumed by both `/api/sketch` and `/api/sketch-url`
- **Related Components:** `frontend/js/timeline.js` (the correct,
  unaffected mechanism for duration-driven playback pacing)
- **Time First Observed:** 2026-10-28, reported directly by the user
  comparing a pre-Phase-10 screenshot against the current build

## Investigation Steps

### 1. Initial Diagnosis
No git history exists for this repository (never committed), so
"compare with Git history" wasn't literally possible; reconstructed the
change from the current session's own record of what Phase 10 added.

### 2. Root Cause Analysis
Re-ran `build_drawing_plan` directly across the UI's full duration range
(2 min through 4 hr) and printed `metadata.durationPlanning.detailBudgetFraction`
and stroke counts for each.

### 3. Key Findings
- `detailBudgetFraction` was `0.138` at 2 minutes, `0.933` at 7 minutes,
  and only reached `1.0` at 10+ minutes -- confirming the reduction was
  real, not a 2-minute-only edge case.
- The long-duration cases (2hr/4hr) were *not* actually affected
  (`detailBudgetFraction: 1.0` throughout), contradicting part of the
  user's initial description of also seeing sparse output there -- worth
  noting as a case where the reported symptom was broader than the
  measured defect, verified rather than assumed.
- Confirmed via a controlled, temporary reintroduction of the removed
  code (captured a screenshot, then immediately reverted) that the
  reduced stroke set really did render visibly thinner hatching in the
  real Canvas renderer, not just in raw stroke counts.

## Root Cause
`select_stroke_budget` stratified-sampled the hatch (tonal) stroke pool
down to fit a capped acceleration factor for short sessions, on the
premise that drawing all ~26,000 strokes at "natural" pace within 2
minutes would require physically impossible per-stroke speed. That
premise was correct, but the fix was wrong: it solved a *pacing* problem
by removing *content*. The correct separation (now implemented) is that
`target_duration_seconds` controls only how fast the frontend plays back
a plan's actions (already handled, pre-existing, by
`frontend/js/timeline.js`'s linear time scaling) -- it must never
determine which strokes exist in the plan at all.

## Prevention / Rule
**Guardrail:** `test_stroke_count_is_identical_across_every_duration_from_2min_to_4hr`
in `backend/test_planner.py` asserts the exact same stroke id list is
produced at every duration from 2 minutes to 4 hours as with no duration
specified at all. Companion tests pin category-level parity (contour,
tonal-band, and colored-stroke counts identical across durations) and
that dark-shading strokes specifically survive at every duration tested.
A corresponding frontend test
(`"buildTimeline never drops actions regardless of the requested target duration"`,
`frontend/test/timeline.test.js`) pins the same invariant on the playback
side.

This closes the gap because any future duration-related change that
reintroduces stroke-count coupling will fail these tests immediately,
rather than only being caught by visual inspection of a finished drawing.

## Solution

### Immediate Fix
Removed `select_stroke_budget`, `_sample_reducible_strokes`, and
`_is_always_kept` entirely. Replaced with `classify_duration_pacing`,
which computes the same `fullNaturalSeconds`/`accelerationFactor`/`pacing`
metadata the frontend's "Time-lapse" badge reads, but **never filters,
samples, or otherwise changes which strokes are in the plan**. Verified
via the real HTTP endpoint that stroke count is now exactly `26042` at
every one of the UI's six duration options, and via a pixel-diff between
the 2-minute and 4-hour final Canvas renders (mean absolute difference
0.17/255, 0.24% of pixels differing by >10/255 -- consistent with ordinary
antialiasing noise, not missing content).

### Long-term Fix
None needed beyond the above -- this *is* the long-term fix, and the new
regression tests make the mistake structurally harder to reintroduce.

## Prevention
- [x] Code changes required (`select_stroke_budget` removed, replaced
      with `classify_duration_pacing` in `backend/planner.py`)
- [x] Regression tests added (backend: 6 new tests; frontend: 1 new test)
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Original feature (now corrected): `reports/ATELIER-2026-10-28-phase-10-duration-aware-artistic-planning.md`
- Report: `reports/ATELIER-2026-10-28-phase-10.1-critical-artistic-regression-fix.md`

## References
- `backend/planner.py` -- `classify_duration_pacing`, `build_drawing_plan`
- `backend/test_planner.py` -- the Phase 10.1 test section
- `frontend/test/timeline.test.js`

---

**Resolved By:** Claude (pair-programming session with tinomupezeni)
**Time to Resolution:** ~1.5 hours (measurement, controlled before/after repro, fix, full regression-test rewrite)
