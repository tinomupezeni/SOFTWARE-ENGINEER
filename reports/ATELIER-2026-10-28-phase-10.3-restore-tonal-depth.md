# Phase 10.3 — Restore Tonal Depth Through Target-Driven Graphite Shading

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Type:** Regression fix (artistic correctness)
**Status:** Completed

## Summary
Diagnosed and fixed the root cause of Atelier's washed-out shading: a
flat, tone-blind per-cell stroke-density ceiling (`MAX_LOCAL_ACCUMULATION = 10`)
caused any sufficiently dark region to converge on nearly identical hatch
density regardless of how much darker it truly was. Measured directly: a
synthetic near-black/dark-gray/medium-gray/light-gray/near-white test
strip rendered its three darkest bands at nearly identical luminance
(177-181/255), and a solid black circle on white rendered as a light gray
disc. Replaced the flat cap with a tone-aware function; re-measured the
same test strip at 54.5/68/155/234/249 -- correct monotonic ordering, real
separation, and the black circle now renders genuinely dark.

## Context / Trigger
Direct user report with a screenshot following Phase 10.1, describing
specific artistic failures (gray fedora, white-ish eye sockets, thin
unconvincing suit shading, "unfinished despite reaching 100%"), with
explicit instructions to diagnose before changing anything and to
distrust automated tests as proof of a fix.

## Scope
**Included:** `backend/sketch.py`'s hatch-density accumulation logic;
synthetic deterministic test images (tonal strip, black circle) run
through the real pipeline and real Canvas renderer; the skull benchmark
re-verified in both artistic styles; cross-category regression check
(landscape, synthetic color portrait, grayscale portrait) for
darkening side effects.

**Excluded, per explicit instruction:** no global darkening filter, no
pasted shadow bitmap, no stroke-count inflation as a first move, no UI
redesign, no new ML models. The renderer's alpha-compositing math was
inspected and confirmed *not* to be the fault before changing anything
there.

## Method
Step 1-3 from the brief, in order, with evidence at each step rather than
assumption: traced tonal information through the pipeline conceptually
first, then built the two synthetic test images the brief specified
(a 5-band luminance strip, a black circle on white), ran both through
the actual `/api/sketch` endpoint and the real Canvas renderer via
Playwright, and measured rendered pixel luminance per region directly
from the screenshots. This located the defect precisely (stroke
generation density, specifically the accumulation cap) before touching
any code, confirmed by also counting raw generated strokes per band
directly from `sketch.image_to_strokes` and finding the three darkest
bands within ~2% of each other in count despite an 8x difference in
source darkness.

## Decisions & Findings

### Root cause (confirmed, not assumed)
`_hatch_pass` gated every candidate stroke seed on
`_accum_at(accum, xi, yi) < MAX_LOCAL_ACCUMULATION`, a single constant
(10) shared by all ten shading bands and every pixel regardless of tone.
Any pixel dark enough to qualify for several bands hit this same flat
ceiling, so "near-black" and "medium-gray" produced nearly identical
stroke density. The renderer's own alpha-compositing (standard
`source-over`, confirmed via code inspection) is fully capable of
reaching genuine darkness given enough layered strokes -- the defect was
entirely in how few strokes the backend ever generated for dark areas,
never in how the frontend composited them. This matches category C from
the brief's root-cause menu ("excessive shading suppression"), not A, B,
D, or E.

### Fix: tone-aware accumulation cap
Added `_accumulation_cap_for_tone(tone_value)`: light/mid tones
(`>= ACCUMULATION_DARKNESS_REFERENCE = 170`) keep the original ceiling
(`MIN_LOCAL_ACCUMULATION = 10`, unchanged -- preserving the Phase 9
"sparse, controlled light wash" character and background cleanliness);
tones approaching true black are linearly allowed up to
`MAX_LOCAL_ACCUMULATION = 60`. `_hatch_pass` now looks up this
per-seed-point tone-dependent cap instead of referencing a single
constant. This is the bounded, analytical approximation the brief asked
for (section/step 4) rather than an expensive rerendering feedback loop:
one extra lookup per candidate seed, no change to processing-time order
of growth.

### Verified, not assumed, that this didn't overcorrect
- Background corners of the re-rendered skull measured 249-251/255 --
  still clean paper; the fix only raises the ceiling for pixels already
  dark enough to pass the background-suppression threshold, which was
  untouched.
- The landscape test image's "ground" region got meaningfully darker
  (mean BGR dropped from ~[153,172,162] to ~[112,138,123]) without
  becoming a solid muddy block -- its pre-existing speckled graphite
  texture (present identically before this fix, confirmed by comparing
  against a saved Phase 9 screenshot of the same image) was preserved,
  not replaced by a flat fill.
- The synthetic full-color portrait's hair and shirt went from a thin,
  sparse wash to solid, rich coverage; skin tones stayed light and legible
  (no muddiness).

## Changes Made
- `backend/sketch.py` -- removed the flat `MAX_LOCAL_ACCUMULATION`
  constant's sole use as a density gate; added `MIN_LOCAL_ACCUMULATION`,
  `ACCUMULATION_DARKNESS_REFERENCE`, and `_accumulation_cap_for_tone`;
  `_hatch_pass` now calls the new function per candidate seed instead of
  comparing against the old constant directly.
- `backend/test_sketch.py` -- updated one existing test's bound (the
  uniformly-dark-image smoke test now legitimately produces far more
  strokes, by design) and added a new Phase 10.3 section: a direct unit
  test of the cap function's monotonicity/bounds, an end-to-end tonal-
  strip density test (with an explicit minimum-separation check, not just
  a bare ordering check -- verified to fail under the old flat-cap
  behavior), a black-circle density test (threshold calibrated above what
  the old cap could ever produce for that shape, also verified to fail
  under the old behavior), a near-white-stays-clean guard, a small-dark-
  region-not-omitted guard, and a determinism check.

## Verification
- **Backend:** 131 tests passed, `pytest -q` (6 new tests this phase).
- **Frontend:** 139 tests passed, `node --test` (unchanged -- no frontend
  code needed to change; the renderer was confirmed not at fault).
- **Measured, real-browser tonal-strip luminance** (source value ->
  rendered luminance, before -> after):
  - near-black (15): 177.6 -> **54.5**
  - dark-gray (70): 177.8 -> **67.9**
  - medium-gray (128): 180.9 -> **155.0**
  - light-gray (190): 234.1 -> 233.8 (unchanged, as intended)
  - near-white (240): 249.3 -> 249.4 (unchanged, as intended)
- **Black circle on white:** rendered as a light-gray hatched disc before
  the fix; rendered as a genuinely dark, nearly solid disc after -- real
  before/after screenshots captured via Playwright.
- **Skull benchmark, both styles, real Canvas renders at 25/50/75/100%:**
  fedora, eye sockets, and suit all now show substantial dark graphite
  buildup; red hatband/tie/cross accents remain intact and legible in
  Faithful Pencil; Graphite Study remains monochrome; background corners
  stay clean; progression from 25% to 100% builds naturally (structure
  complete early, tone deepens gradually, no mechanical jump to full
  darkness).
- **Regression tests deliberately proven meaningful:** both new density
  tests were run against a monkeypatched reversion to the old flat cap
  and confirmed to fail, not just pass trivially.

## Follow-ups / Deferred
- Contour "scratchiness" (hat brim, teeth, jacket seams) was separately
  inspected at high zoom in the corrected render and did not show obvious
  doubled or fragmented boundaries; the brief's complaint about this may
  have been partly a perceptual side effect of the washed-out tone itself
  (thin lines read as "scratchy" when there's no supporting dark mass
  underneath them). Not independently reproduced as a distinct defect in
  this pass -- flagging rather than claiming fixed, since it wasn't
  separately isolated the way the tonal defect was.
- `MIN_LOCAL_ACCUMULATION = 10`, `MAX_LOCAL_ACCUMULATION = 60`, and
  `ACCUMULATION_DARKNESS_REFERENCE = 170.0` are documented estimates
  calibrated against the specific synthetic test images and the skull
  benchmark, consistent with the rest of the planner/sketch heuristics'
  "estimates, not measurements" ethos -- not exhaustively tuned against a
  wide corpus.

## References
- `ATELIER-2026-10-28-flat-accumulation-cap-collapsed-dark-tones.md`
- `backend/sketch.py` -- `_accumulation_cap_for_tone`, `_hatch_pass`
- `backend/test_sketch.py` -- the Phase 10.3 test section

---

**Completed By:** Claude (pair-programming session with tinomupezeni)
**Duration:** Single focused session (Phase 10.3, immediately following Phase 10.1)
