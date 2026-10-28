# Flat per-cell accumulation cap collapsed all dark tones into one gray

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Environment:** Development
**Severity:** Critical
**Status:** Resolved

## Summary
`sketch.py`'s `MAX_LOCAL_ACCUMULATION` was a single flat constant (10)
bounding how many hatch strokes could seed in any 10x10px grid cell,
regardless of how dark the underlying source pixel actually was. Any tone
dark enough to qualify for several of the ten shading bands hit this same
ceiling, so a near-black region and a medium-gray region converged on
nearly identical stroke density and rendered as nearly the same shade of
gray. A solid black circle on white rendered as a light gray hatched
disc, not a dark one -- the exact failure mode a real artist's drawing
should never produce.

## Symptoms
- The skull benchmark's fedora, eye sockets, and suit all rendered as
  medium gray with visible individual hatch lines, never building up to
  convincing dark graphite, despite the UI reporting "100% complete."
- Measured directly: a synthetic 5-band strip (source values 15/70/128/190/240)
  rendered the three darkest bands at nearly identical luminance (177.6,
  177.8, 180.9 out of 255) in the real Canvas output -- a near-black
  source pixel looked barely darker than a medium-gray one.
- A solid black circle (BGR ~10,10,10) on a white background rendered as
  a light-gray hatched disc, not a dark one.

## Environment Details
- **Server/Host:** local dev (`uvicorn` on 127.0.0.1:8787)
- **Services Affected:** `backend/sketch.py` -- `_hatch_pass`'s
  seed-acceptance gate, used by both neutral and colored hatching
- **Related Components:** `frontend/js/renderer.js` (confirmed *not* at
  fault -- its alpha-compositing math can reach genuine darkness given
  enough overlapping strokes; the strokes just weren't being generated)
- **Time First Observed:** 2026-10-28, direct user report with a
  screenshot, following up on Phase 10.1

## Investigation Steps

### 1. Initial Diagnosis
Per the task's explicit instruction not to assume a cause, built a
deterministic synthetic test image (5 vertical bands from near-black to
near-white, plus a solid black circle on white), ran both through the
real pipeline, and inspected the real Canvas output via Playwright --
not just raw stroke data.

### 2. Root Cause Analysis
Measured actual rendered pixel luminance per band directly from the
screenshot (`cv2`), and separately counted generated strokes per band
directly from `sketch.image_to_strokes`'s output.

### 3. Key Findings
- Stroke counts per band (pre-fix): near-black 3011, dark-gray 3000,
  medium-gray 2950, light-gray 1112, near-white 1 -- the three darkest
  bands are within 2% of each other despite an 8x difference in source
  darkness.
- `_hatch_pass` accepted a candidate seed only if
  `_accum_at(accum, xi, yi) < MAX_LOCAL_ACCUMULATION`, where
  `MAX_LOCAL_ACCUMULATION = 10` was a single constant shared by every
  band and every pixel, regardless of tone. Once a cell's count reached
  10 (which it does quickly in any region dark enough to qualify for
  multiple bands), no darker band's additional strokes could add any
  further density there -- a near-black and a medium-gray pixel both hit
  this identical ceiling.
- `renderer.js`'s alpha-compositing (standard `source-over`) was
  confirmed capable of reaching real darkness given enough layered
  strokes -- the defect was entirely in how few strokes the backend ever
  generated for a given dark area, not in how the frontend composited them.

## Root Cause
A single flat per-cell stroke-density ceiling, applied uniformly
regardless of local source darkness, meant "how many hatch marks are
allowed to overlap here" was decoupled from "how dark should this area
actually be" -- the two quantities need to scale together for tonal depth
to be reproduced at all.

## Prevention / Rule
**Guardrail:** `test_hatch_density_strictly_increases_with_source_darkness`
and `test_a_black_circle_on_white_gets_dense_not_sparse_coverage` in
`backend/test_sketch.py`. Both were verified to **fail** when the fix is
reverted (`_accumulation_cap_for_tone` monkeypatched back to a flat `10`):
the density test catches the specific "technically decreasing but
visually identical" failure mode (band counts within 3% of each other)
via an explicit minimum-separation check, not just a bare `>` chain which
the original bug would have passed; the circle test's threshold (8,000
strokes) was calibrated above what the old flat cap could produce for
that exact shape (~2,761), not an arbitrary "more than zero" check.

This closes the gap because stroke-count alone is a weak proxy for
perceived darkness (confirmed: the old flat cap still produced thousands
of strokes, just not enough, and not dense enough locally) -- both tests
were deliberately strengthened past a naive threshold until proven to
actually discriminate old from new behavior.

## Solution

### Immediate Fix
Replaced the flat `MAX_LOCAL_ACCUMULATION` constant with
`_accumulation_cap_for_tone(tone_value)`: light/mid tones keep the
original ceiling (`MIN_LOCAL_ACCUMULATION = 10`), tones approaching true
black are linearly allowed up to `MAX_LOCAL_ACCUMULATION = 60`, referenced
against `ACCUMULATION_DARKNESS_REFERENCE = 170.0` (tones at/above this
already get the minimum). `_hatch_pass` now looks up this per-seed-point
tone-dependent cap instead of a single constant.

### Long-term Fix
None needed beyond the above.

## Prevention
- [x] Code changes required (`_accumulation_cap_for_tone` in `backend/sketch.py`)
- [x] Regression tests added, and verified to fail without the fix
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Report: `reports/ATELIER-2026-10-28-phase-10.3-restore-tonal-depth.md`
- Follows: `ATELIER-2026-10-28-duration-aware-stroke-budget-thinned-out-artwork.md` (Phase 10.1 -- a different cause of thin-looking output, already fixed; this is the deeper, pre-existing tonal defect underneath it)

## References
- `backend/sketch.py` -- `_accumulation_cap_for_tone`, `_hatch_pass`
- `backend/test_sketch.py` -- the Phase 10.3 tonal-depth test section

---

**Resolved By:** Claude (pair-programming session with tinomupezeni)
**Time to Resolution:** ~1 hour (synthetic test image construction, real-browser measurement, fix, test-strengthening pass)
