# Phase 10 — Duration-Aware Artistic Planning

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Type:** Feature build (audit-driven)
**Status:** Completed

## Summary
Made Atelier's drawing sessions behave believably across the full
2-minute-to-4-hour duration range. Previously the backend always produced
every stroke and the frontend linearly time-scaled the whole action
sequence to fit whatever duration was requested -- fine at the natural
pace (~64 minutes for the skull benchmark) but physically absurd at 2
minutes (~200+ strokes/second) and requiring a strokes-count-respecting
detail budget to avoid pretending that pace is a real pencil in motion.
Added a backend-side, duration-aware stroke budget that reduces hatch
detail (never structural contours or color accents) for short sessions,
an explicit "time-lapse" pacing label surfaced in the UI, and two
real-pacing fixes (a batch-size and a travel-speed-tiering change)
informed by a concrete per-stage timing audit. A real defect in the
playback engine's frame-scheduling was found and fixed along the way.

## Context / Trigger
User-specified "Phase 10" brief: a fixed stroke sequence cannot produce
equally believable drawing behavior at both duration extremes; Atelier
needed to choose an appropriate balance between final image quality,
stroke count, detail level, movement realism, and the selected duration,
without silently squeezing every stroke into whatever time was picked.

## Scope
**Included:** `backend/planner.py` (duration-aware detail budget,
stage-pacing constants), `backend/main.py` (duration parameter plumbing +
validation), `frontend/main.js`/`index.html`/`style.css` (duration sent to
backend, a "Time-lapse" badge), `frontend/js/player.js` (the
frame-scheduling fix the audit surfaced), full backend/frontend test
suites, and real-browser validation across 5 image categories at both
duration extremes.

**Excluded:** no new ML models, no change to the existing six-stage
artistic architecture's ordering, no change to the planner/playback wire
contract's required fields (purely additive metadata).

## Method
Audit first, then fix: measured the existing planner's actual natural
duration and its per-stage time/travel breakdown on the skull benchmark
before changing anything, used those real numbers to decide what was
actually wrong (not assumed), then designed the detail-budget mechanism
around the measured natural-time/overhead ratio. Verified via real
Playwright/Chrome screenshots (not just passing unit tests) across both
duration extremes and five image categories, following the same
"visually inspect the actual Canvas output" discipline established in
Phase 9.

## Decisions & Findings

### Audit (requirement 1)
Built `audit_duration.py`/`audit_duration2.py` scratch scripts that call
the real pipeline and walk `plan.actions` directly, attributing cumulative
time to the stage active at each point. Key findings for the skull
benchmark:
- Natural (backend-estimated) total time: **~64 minutes**, not 4 hours --
  meaning the "problem extreme" is the *short* end of the range (2
  minutes needs ~32x acceleration), not the long end (4 hours is actually
  *slower* than natural pace, ~3.75x slowdown, which is unremarkable).
- Pen-up travel was **~54% of total time**, comparable to actual drawing
  -- not a rounding error, a first-order cost.
- Stage 3 ("light tonal blocking") alone held **~70% of total natural
  time**, and more than half of *that* stage's own time was pure travel,
  not drawing -- a direct consequence of its small (6-stroke) batch size
  forcing a fresh session, and therefore travel, extremely often.
- Structural contours (stage 2) completed within the first ~6% of the
  timeline; deep shading (stage 5) occupied only the final ~2%.

### Pacing fixes (requirement 4, grounded in the audit)
- Raised `STAGE_LIGHT_TONAL_BLOCKING`'s batch size from 6 to 14 (still the
  smallest batch, preserving the "sparse global wash" character).
- Added a two-tier travel speed: a fast "local hop" speed
  (`LOCAL_HOP_SPEED_PX_PER_SEC = 2400`, for moves under 60px -- modeling a
  wrist-flick to the next nearby mark) versus the existing cross-page
  travel speed, reducing inflated travel cost for the overwhelmingly
  common short-hop case between adjacent hatch strokes.

### Duration-aware detail budget (requirements 2/3)
`planner.select_stroke_budget()`: construction strokes, structural
contour lines, and any color accent are always kept in full (cheap in
count, carry all of a drawing's recognizability). The remaining
(reducible) hatch strokes are budgeted to fit the requested duration
played at no more than `MAX_BELIEVABLE_SPEED_FACTOR = 8.0` times their
natural pace; if the full reducible set already fits, nothing is cut.
Selection within the reducible pool is stratified by (region, artistic
stage) and stride-sampled from each stratum's own higher-importance end --
never "first N", never a single global importance cutoff -- so a reduced
budget still covers every spatial region and every tonal band.
Deterministic (seeded), and the whole mechanism is opt-in: omitting
`target_duration_seconds` keeps exactly the pre-Phase-10 behavior.

A plan's `metadata.durationPlanning` now documents the decision
(`detailBudgetFraction`, `strokesKept`/`strokesDropped`,
`accelerationFactor`, and a `pacing` label of `"natural"` or
`"timelapse"`), surfaced in the UI as a small "Time-lapse" badge next to
the progress readout -- shown whenever the session plays faster than
`TIMELAPSE_LABEL_THRESHOLD = 1.15x` its own (possibly already-reduced)
natural pace, so a sped-up session is never silently presented as if it
were real-time.

### A real playback-engine defect found via the phase's own verification tooling
While capturing duration-comparison screenshots, the on-screen progress
percentage read implausibly small values at deliberately-seeked
checkpoints. Root cause: `Player._scheduleNext()` armed a new
`requestAnimationFrame` registration without canceling any prior one --
invisible under normal playback, but a debug "seek to fraction" helper
driving `_tick` manually and repeatedly leaked dozens of pending
registrations, all of which fired moments later with the browser's own
tiny real elapsed time and overwrote the correct progress. Fixed and
regression-tested; full detail in
`ATELIER-2026-10-28-player-leaks-pending-animation-frames-on-manual-seek.md`.
This was a genuine, if latent, engine defect -- not a documentation-only
or test-only issue -- so it gets its own bug-log entry rather than being
folded into this report.

## Changes Made
- `backend/planner.py` -- `select_stroke_budget`, `_sample_reducible_strokes`,
  `_is_always_kept`, new constants (`MAX_BELIEVABLE_SPEED_FACTOR`,
  `NATURAL_TIME_OVERHEAD_MULTIPLIER`, `MIN_DETAIL_BUDGET_FRACTION`,
  `TIMELAPSE_LABEL_THRESHOLD`), `STAGE_BATCH_SIZE` tuning, the
  `LOCAL_HOP_*` travel-speed tier, `build_drawing_plan(..., target_duration_seconds=None)`.
- `backend/main.py` -- `durationSeconds` form/body field on both
  `/api/sketch` and `/api/sketch-url`, range-validated to the UI's
  2-minute-to-4-hour range.
- `frontend/main.js` -- sends `durationSeconds` with the sketch request,
  a `pacing-badge` element toggle, the `_scheduleNext` fix's test-only
  diagnostic hooks.
- `frontend/js/player.js` -- the `_scheduleNext` fix.
- `frontend/index.html`, `frontend/style.css` -- the "Time-lapse" badge.
- `backend/test_planner.py` (+8 tests), `backend/test_main.py` (+4 tests),
  `frontend/test/player.test.js` (+1 regression test).

## Verification
- **Backend:** 123 tests passed (111 pre-existing + 12 new), `pytest -q`.
- **Frontend:** 138 tests passed (137 pre-existing + 1 new), `node --test`.
- **Real browser verification** (Playwright driving the system's actual
  Chrome): 5 image categories (colored skull, a synthetic full-color
  portrait exercising skin-tone/hair/clothing colors, a real grayscale
  pencil-portrait photograph, a synthetic landscape, a synthetic
  geometric-shapes image) each at both 2 minutes and 4 hours -- 10 runs,
  zero page errors, "Time-lapse" badge correctly shown only on the
  2-minute runs. Visually inspected progression at 10/25/50/75/90/100% for
  the skull at both durations: structure completes early and
  proportionally identically at both durations (same artistic story,
  different real-world pace), tone visibly builds through the middle of
  the session, color accents remain intact and legible even in the
  heavily-budgeted 2-minute run, and the 4-hour run retains full,
  undiminished detail (`detailBudgetFraction: 1.0`).

### Benchmarks (skull benchmark, all 6 UI duration options)

| Duration | Strokes kept | Detail budget | Pacing | Acceleration |
|---|---|---|---|---|
| 2 min | 4,729 / 26,042 | 13.8% | timelapse | 8.01x (capped) |
| 15 min | 26,042 / 26,042 | 100% | timelapse | 3.96x |
| 30 min | 26,042 / 26,042 | 100% | timelapse | 1.98x |
| 60 min | 26,042 / 26,042 | 100% | natural | 0.99x |
| 120 min | 26,042 / 26,042 | 100% | natural | 0.49x |
| 240 min | 26,042 / 26,042 | 100% | natural | 0.25x |

Budget scales smoothly (verified at 3/4/5/7/10/12-minute intermediate
points, not just the 6 UI options) rather than jumping discontinuously
between the nearest two dropdown values. Plan build time stayed
0.6s-1.9s across all cases -- no measurable regression from the new
budgeting step.

## Follow-ups / Deferred
- `MAX_BELIEVABLE_SPEED_FACTOR = 8.0` and the other new constants are
  documented estimates (consistent with the rest of the planner's
  heuristics), not derived from a real human-drawing-speed study -- a
  future pass could validate against real reference footage if more
  precision is ever needed.
- The detail budget only ever reduces *hatch* strokes; an image whose
  recognizability depends heavily on a very large number of structural
  contour lines (unlike the tested categories) would keep all of them
  regardless of duration, which could still produce a fast per-line pace
  at the very shortest duration for such an image -- not observed in any
  of the 5 tested categories, but not proven impossible either.

## References
- `ATELIER-2026-10-28-player-leaks-pending-animation-frames-on-manual-seek.md`
- `backend/planner.py`, `backend/main.py`
- `frontend/js/player.js`, `frontend/main.js`, `frontend/index.html`, `frontend/style.css`

---

**Completed By:** Claude (pair-programming session with tinomupezeni)
**Duration:** Single extended session (Phase 10 of a multi-phase build)
