# Linear darkness-to-cap mapping over-shaded low-contrast photos

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Phase 10.3's tone-aware accumulation cap (`_accumulation_cap_for_tone` in
`backend/sketch.py`) used a linear mapping from source darkness to the
allowed per-cell stroke-density ceiling. While this correctly fixed the
Phase 10.3 regression (true near-black regions were under-shaded), the
linear ramp also gave ordinary photographic midtones a meaningfully
elevated cap, causing a deliberately low-contrast test photo (narrow
tonal range, nothing darker than roughly tone~90) to render as a dense,
nearly solid dark mass -- losing the subtle, low-contrast character of
the source.

## Symptoms
- A synthetic low-contrast photo (gradient background + two faint
  silhouette ellipses, tones roughly 90-180) rendered with very dense,
  almost solid dark hatching across most of its upper two-thirds in the
  real Canvas output, despite having no genuinely dark source pixels.

## Environment Details
- **Server/Host:** local dev (`uvicorn` on 127.0.0.1:8787)
- **Services Affected:** `backend/sketch.py` -- `_accumulation_cap_for_tone`
- **Related Components:** part of the Phase 10.3 tonal-depth fix
- **Time First Observed:** 2026-10-28, during Phase 10.4's explicit task
  to validate the Phase 10.3 accumulation cap against diverse image
  categories, including a low-contrast photograph

## Investigation Steps

### 1. Initial Diagnosis
Rendered the low-contrast benchmark image through the real pipeline and
real Canvas renderer (Playwright) as part of the Phase 10.4 benchmark
gallery; the result looked visibly denser/darker than the subtle source
character warranted.

### 2. Root Cause Analysis
Computed `_accumulation_cap_for_tone`'s output across a range of tone
values directly: `tone=90` (this image's darkest gradient edge) mapped to
a cap of ~34 -- nearly 3.5x the original conservative floor of 10, despite
tone=90 being a fairly ordinary midtone, nowhere near true black.

### 3. Key Findings
- The linear formula `darkness = (170 - tone) / 170` treats *any* tone
  below the 170 reference point as meaningfully "dark" on a straight-line
  scale reaching its maximum only at tone=0 -- so moderate midtones (70-150)
  already sit 50%+ of the way up the ramp.
- Comparing the pre-fix flat cap of 10 against this same image directly
  showed it was already fairly dense (12,941 hatch strokes) due to the
  pre-existing 10-band hatch table naturally layering many bands across a
  broad gradient -- the linear cap added roughly 35% more strokes on top
  of that pre-existing characteristic, not the entire visual effect.

## Root Cause
A linear darkness-to-cap mapping does not distinguish "ordinary midtone"
from "approaching true black" sharply enough -- both get a meaningfully
elevated cap relative to the conservative floor, when only the latter
should.

## Prevention / Rule
**Guardrail:** the Phase 10.3 tonal-separation tests
(`test_hatch_density_strictly_increases_with_source_darkness`,
`test_a_black_circle_on_white_gets_dense_not_sparse_coverage` in
`backend/test_sketch.py`) continue to pass with real margin after this
change, confirming the fix for over-shading did not reintroduce the
original under-shading regression. The benchmark suite added in this same
phase (`backend/benchmarks/`, `backend/test_benchmarks.py`) now also
tracks `low_contrast_photo`'s rendered dark-coverage percentage as a
committed fixture, so a future change that re-introduces over-shading for
this specific image category would show up as fixture drift.

This closes the gap because the benchmark suite gives low-contrast,
subtle-tone images their own tracked regression fixture, not just the
high-drama skull benchmark -- a category of image the project had not
previously tested against the accumulation-cap logic at all.

## Solution

### Immediate Fix
Squared the darkness fraction in `_accumulation_cap_for_tone` before
scaling it into the cap range. Moderate midtones now get a much more
modest cap (~21 at tone 90, ~13 at tone 128, close to the original floor
of 10) while true near-black tones keep nearly the same large cap as
before (~52 at tone 15 vs. ~56 previously) -- the dark end of the Phase
10.3 fix is preserved; only the midtone amplification is reined in.

### Long-term Fix
None needed beyond the above.

## Prevention
- [x] Code changes required (`_accumulation_cap_for_tone` in `backend/sketch.py`)
- [x] Regression tests added (a `low_contrast_photo` benchmark fixture tracking rendered dark-coverage)
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Follows: `ATELIER-2026-10-28-flat-accumulation-cap-collapsed-dark-tones.md` (the Phase 10.3 fix this refines)
- Report: `reports/ATELIER-2026-10-28-phase-10.4-benchmark-report.md`

## References
- `backend/sketch.py` -- `_accumulation_cap_for_tone`
- `backend/benchmarks/images/low_contrast_photo.png`, `backend/benchmarks/fixtures/low_contrast_photo.json`

---

**Resolved By:** Claude (pair-programming session with tinomupezeni)
**Time to Resolution:** ~20 minutes
