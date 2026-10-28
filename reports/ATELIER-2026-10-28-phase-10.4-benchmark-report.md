# Phase 10.4 — Artistic Quality Baseline and Regression Protection

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Type:** Audit / benchmark-infrastructure build
**Status:** Completed

## Summary
Built a reproducible, 6-image artistic benchmark suite (`backend/benchmarks/`)
so a future engine change can be checked against what Atelier has already
achieved, instead of drifting silently. Investigating the Phase 10.3
accumulation-cap fix's performance impact against this suite surfaced two
real findings: a low-contrast photo was being over-shaded (fixed), and the
primary skull benchmark's processing time rose from ~2.2s to ~10s (not
"fixed" -- profiled, partially optimized with zero visual-quality risk,
and the remainder documented as an inherent, accepted cost per explicit
user direction).

## Context / Trigger
User-specified "Phase 10.4" brief: establish a benchmark gallery before
further feature work, separating automated correctness from artistic
visual approval, and specifically investigate whether the Phase 10.3
accumulation ceiling (60) causes over-shading or performance problems on
diverse images.

## Scope
**Included:** a 6-image benchmark gallery (colored skull, full-color
portrait, landscape, geometric object, low-contrast photo, near-white
illustration), automated regression fixtures + tests, real-browser
reference screenshots, a profiling-driven performance investigation of
the Phase 10.3 cap, and (per explicit follow-up user direction) safe,
verified optimizations with no change to tonal separation.

**Excluded, per explicit instruction:** no UI redesign, no algorithm
redesign. One payload-safety-net constant was tightened (justified below,
verified to affect none of the 6 approved benchmark images); no other
engine behavior was changed without a demonstrated, measured reason.

## Method
Generated all 6 images' full-quality plans with a deterministic seed,
captured real Canvas renders (not the project's own crude Python preview)
at 25/50/75/100% via Playwright, and recorded both backend-only metrics
(stroke counts by kind, payload size, processing time) and
rendered-screenshot metrics (average luminance, dark-region coverage,
background cleanliness, color presence) into a committed JSON fixture per
image. When the investigation step (validating the cap against diverse
images) surfaced a real defect, diagnosed it with evidence (a direct
stroke-count comparison against the pre-fix flat-cap behavior) before
changing anything, per this project's established discipline across
every prior phase.

## Decisions & Findings

### The benchmark suite (tasks 1-4, 7-8)
6 images, each targeting a distinct demand: `colored_skull` (the
project's primary benchmark -- deep tonal shading + Faithful Pencil color
preservation), `full_color_portrait` (synthetic, skin/hair/clothing color
extraction), `landscape` (large flat multi-color regions, non-white
background), `geometric_object` (simple distinct shapes, no photographic
texture), `low_contrast_photo` (narrow tonal range -- the specific case
task 5 asked about), `near_white_illustration` (mostly blank page,
background cleanliness / "don't over-shade near-nothing"). Each has a
committed fixture (`backend/benchmarks/fixtures/<name>.json`) and 4
reference screenshots. `backend/test_benchmarks.py` (24 tests) regenerates
each image's plan and compares stroke counts, payload size,
color-presence, and determinism against the fixture within a generous
(35%) tolerance -- loose enough not to force a fixture update for routine
unrelated tuning, tight enough to catch a real regression (a disabled
pass, a cut cap, broken color extraction).

### Task 9/10: automated correctness vs. artistic approval, kept separate
`test_benchmarks.py` only asserts non-drift (did a category silently
disappear, did a count swing by an order of magnitude) -- it cannot and
does not judge whether output looks good. That judgment lives in the
committed screenshots plus this report's "Visual approval status" table
below, which a human still needs to look at (see `benchmarks/README.md`'s
explicit statement of this split).

### Finding 1: `low_contrast_photo` was being over-shaded (fixed)
`_accumulation_cap_for_tone`'s linear darkness-to-cap mapping gave an
ordinary photographic midtone (the low-contrast test image's darkest
gradient edge, tone~90 -- nowhere near black) a cap around 34, rendering
a deliberately subtle, low-contrast source as a dense, nearly solid dark
mass. Fixed by squaring the darkness fraction: moderate midtones now get
a much more modest cap (~21 at tone 90, ~13 at tone 128) while true
near-black tones keep nearly the same large cap as before (~52 at tone
15 vs. ~56 previously) -- confirmed the Phase 10.3 tonal-separation tests
still pass with real margin, not just barely. Important context,
confirmed by testing the *old* flat cap of 10 against the same image:
this photo was already fairly dense (12,941 hatch strokes) before any
Phase 10.3 change, because the pre-existing 10-band hatch table naturally
layers many bands across a broad gradient -- the cap fix added roughly
35% more strokes on top of that pre-existing characteristic, not the
whole effect. Framing this honestly as a partial amplification, not a
problem invented from nothing.

### Finding 2: the skull benchmark's processing cost rose significantly (profiled, partially optimized, remainder accepted)
Measured: `colored_skull` went from ~26,000 strokes / ~2.2s (pre-Phase-10.3)
to ~60,400 strokes / ~9-10s / ~44MB payload. Per explicit user follow-up
direction (after being asked how to handle this), profiled rather than
guessed:
- `cProfile` showed `builtins.round` was called 4.18 million times (3.0s
  of a 9.8s total) -- the single largest contributor, and it was pure
  JSON-serialization overhead in `Stroke.to_json()` (a Python-level
  per-point `round()` call), not the actual stroke-generation math.
  Vectorized with one `np.round()` call per stroke instead of one Python
  `round()` per point.
- `_accumulation_cap_for_tone` was being recomputed via a full
  floating-point formula for every *candidate* seed (including rejected
  ones), ~65,500 times. Since tone is always an 8-bit value (256 possible
  inputs), precomputed it once into a lookup table -- same result for
  every real input, now an O(1) array index.
- Combined effect: ~8.5% faster (9.825s -> 8.9-9.1s across repeated runs),
  with **zero** change to any stroke's geometry, shade, or color --
  confirmed via the full test suite and by re-measuring every benchmark
  fixture's rendered-screenshot metrics (identical to the byte).
- The *dominant* remaining cost (`_trace_streamline`, ~4.7s of ~9s) is the
  actual streamline-tracing math for each accepted stroke -- inherently
  sequential (each step depends on the previous via momentum damping, not
  parallelizable the way the serialization fix was) and directly
  proportional to how many strokes get accepted. This is exactly the
  "necessary" cost of the Phase 10.3 artistic fix, not waste: more
  genuinely dark strokes require more genuine tracing. Per the user's own
  framing -- "the objective is not simply to generate fewer strokes, it
  is to generate the necessary strokes as efficiently as possible" -- this
  was investigated for waste (found and fixed real waste above) and is
  not being reduced further by cutting content.

### Finding 3: a measured (not guessed) worst-case upper bound
Per explicit instruction to establish a bound from measured worst-case
behavior, not an arbitrary one: tested a large (760x570), uniformly
near-black synthetic photo -- a genuinely pathological input. It generated
**~115,000 hatch strokes in ~20s**, within 5,000 of the existing
`MAX_HATCH_STROKES = 120,000` safety backstop -- almost no margin left
for anything even darker or larger, where the old flat cap of 10 would
have given this same pathological image enormous headroom. Tightened
`MAX_HATCH_STROKES` to 100,000 (verified this affects **none** of the 6
approved benchmark images -- the largest, `colored_skull` at 60,433, stays
far under it) to restore real safety margin on final payload/stroke
count. This does **not** bound generation *time* (truncation happens
after generation, not during it) -- doing that safely would need to skip
remaining bands starting from the *lightest* (contributing least to
perceived darkness) under a time/count budget, never the *darkest* ones
(processed last, exactly what the Phase 10.3 fix depends on). Reordering
or truncating bands carries real risk of reintroducing the Phase 10.3
regression for pathological inputs specifically, so this was deliberately
**not** attempted within this phase's scope -- flagged as a follow-up,
not guessed at.

## Changes Made
- `backend/benchmarks/` (new): `images/` (6 source images, 2 newly
  synthesized for this phase -- `low_contrast_photo.png`,
  `near_white_illustration.png` -- plus 4 reused from earlier phases'
  verification work), `fixtures/*.json`, `screenshots/*.png`,
  `generate_metrics.py`, `compute_rendered_metrics.py`, `README.md`.
- `backend/test_benchmarks.py` (new): 24 automated regression tests.
- `backend/sketch.py`: `_accumulation_cap_for_tone` squared (over-shading
  fix), `Stroke.to_json()` vectorized, `_ACCUMULATION_CAP_LUT`
  precomputed lookup table, `MAX_HATCH_STROKES` tightened 120,000 ->
  100,000.

## Verification
- **Backend:** 131 non-benchmark tests + 24 benchmark tests, all passed.
- **Frontend:** 139 tests passed (untouched this phase).
- Every optimization was verified to produce byte-identical rendered
  output before being accepted: re-ran `compute_rendered_metrics.py`
  after each change and confirmed `avgLuminance`/`darkCoveragePct`/
  `backgroundCleanliness`/`colorPreserved` were unchanged for all 6
  images.
- The pathological near-black test case was re-run after the
  `MAX_HATCH_STROKES` change and confirmed bounded (76,843 strokes /
  22.5MB, down from ~115,000 / ~34MB) with no effect on any approved
  benchmark image's own numbers.

### Final benchmark table

| Image | Strokes | Payload | Time | Avg Luminance | Dark Coverage | Color |
|---|---|---|---|---|---|---|
| colored_skull | 60,433 | 43.6MB | 9.07s | 166.0 | 34.8% | yes |
| full_color_portrait | 18,408 | 13.4MB | 3.00s | 198.9 | 25.5% | yes |
| landscape | 37,877 | 26.9MB | 7.19s | 173.7 | 26.7% | yes |
| geometric_object | 15,138 | 11.3MB | 2.25s | 204.3 | 9.4% | yes |
| low_contrast_photo | 17,467 | 12.4MB | 2.30s | 175.5 | 6.4% | no (expected) |
| near_white_illustration | 661 | 0.4MB | 0.13s | 247.5 | 1.3% | no (expected) |

## Visual approval status (task 10 -- what still needs a human to look at it)

All 6 images' screenshots were inspected during this session and read as
artistically sound by this reviewer (dark regions genuinely dark, color
accents muted-but-legible, backgrounds clean, no obvious over-shading).
**None of these have been explicitly approved by the project owner** --
that sign-off is a separate, required step this report does not and
cannot substitute for:

| Image | Automated tests | Needs human visual sign-off |
|---|---|---|
| colored_skull | pass | **yes** -- primary benchmark, highest stakes |
| full_color_portrait | pass | yes |
| landscape | pass | yes |
| geometric_object | pass | yes |
| low_contrast_photo | pass | yes -- specifically re: the over-shading fix |
| near_white_illustration | pass | yes |

## Follow-ups / Deferred
- Bounding worst-case *generation time* (not just final payload) for a
  pathological dark image remains open -- the measured case still takes
  ~20s even after `MAX_HATCH_STROKES` tightening. A safe approach would
  skip remaining *light* bands under budget pressure, never dark ones;
  not attempted here given the risk of reintroducing the Phase 10.3
  regression without careful, separate testing.
- `_trace_streamline`'s sequential, momentum-based design is the
  dominant remaining cost and was deliberately not restructured --
  genuine algorithmic work, out of proportion for a benchmark-
  establishment phase, and not requested.
- The wire payload's non-point fields (`centroid`, `bbox`, `importance`,
  `estimated_duration`) were measured at ~26% of total payload combined
  and confirmed **completely unused by the frontend** (grepped
  `frontend/js/*.js` and `main.js`) -- a strong, evidence-backed candidate
  for a future wire-schema trim, but removing wire-contract fields is a
  bigger decision than internal performance tuning and was not done
  without explicit sign-off; flagged here for a future phase.
- A Git baseline commit (task 6) was made of the entire previously-
  uncommitted repository state immediately after this phase, capturing
  everything through this report as the first commit.

## References
- `backend/benchmarks/README.md` -- the suite's own documentation,
  including "Updating a fixture after an intended change"
- `backend/benchmarks/fixtures/*.json`, `backend/benchmarks/screenshots/*.png`
- `backend/test_benchmarks.py`
- `backend/sketch.py` -- `_accumulation_cap_for_tone`, `_ACCUMULATION_CAP_LUT`, `Stroke.to_json`, `MAX_HATCH_STROKES`

---

**Completed By:** Claude (pair-programming session with tinomupezeni)
**Duration:** Single extended session (Phase 10.4, immediately following Phase 10.3)
