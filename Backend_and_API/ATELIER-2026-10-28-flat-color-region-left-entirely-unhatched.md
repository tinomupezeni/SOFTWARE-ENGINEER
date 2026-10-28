# Flat-filled color region silently gets zero colored strokes

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
In Atelier's "Faithful Pencil" color-preservation pass (`backend/sketch.py`,
`_extract_colored_strokes`), a region with a genuinely flat/near-uniform
fill color (e.g. a solid-color shape, or a large flat area of a real
photograph) could end up with its entire tone-band ladder calibrated
outside where its actual pixels sit, producing zero hatch strokes for that
region — rendered as a completely blank/unfilled area despite being
correctly detected as a colored region.

## Symptoms
- A synthetic green ellipse detected as its own correctly-colored region
  (confirmed via direct `_extract_colored_strokes` call) still rendered
  with zero visible fill in the real browser Canvas output — only its
  contour line was visible.
- A large flat "ground" region in a synthetic landscape image similarly
  rendered completely blank.

## Environment Details
- **Server/Host:** local dev (`uvicorn` on 127.0.0.1:8787)
- **Services Affected:** `backend/sketch.py` color-region extraction (Faithful Pencil style)
- **Related Components:** `_extract_colored_strokes`, `_hatch_pass`
- **Time First Observed:** 2026-10-28, during Phase 9 cross-category verification

## Investigation Steps

### 1. Initial Diagnosis
Confirmed via direct Python call that the region was detected (correct
area, correct median color) but produced only ~20 hatch strokes against a
sibling region's ~2700+.

### 2. Root Cause Analysis
Printed `region_tone.min()/.max()` and the derived `tone_min + span * fraction`
band cutoffs against the actual tone value at the unfilled pixel:

```bash
.venv/bin/python3 debug_ellipse5.py / debug_land3.py
```

### 3. Key Findings
- The region's dominant (mode) tone value sat very close to one extreme
  of its literal min/max range, with the opposite extreme set by a small
  number of antialiased/bilateral-blur-blended boundary pixels.
- The three band cutoffs (`tone_min + span * {0.80, 0.45, 0.15}`) assume
  tone is spread roughly evenly across `[tone_min, tone_max]`. For a
  region whose real population clusters at one end, every cutoff can fall
  strictly below (or at) the dominant tone value, so the `tone < max_intensity`
  check in `_hatch_pass` rejects the entire interior.
- An intermediate fix (percentile-based `tone_min`/`tone_max` instead of
  literal min/max) fixed the small-ellipse case but not the large
  flat-ground case, where the mode sat at the *high* end of even the
  percentile-based span — proving the real defect was the fixed-fraction
  assumption itself, not just outlier sensitivity in picking the endpoints.

## Root Cause
The color tone-band ladder computed cutoffs as fixed fractions of a
region's tone range, which only produces correct coverage when tone is
roughly uniformly distributed across that range — false for flat-filled
or strongly skewed regions, which are common in non-photographic (vector
graphics, UI mockups) and even some photographic (sky, skin, flat ground)
imagery.

## Prevention / Rule
**Guardrail:** regression test `test_a_flat_filled_region_still_gets_hatched_not_left_blank`
in `backend/test_sketch.py`, asserting a solid-filled synthetic shape
produces more than 20 colored strokes. This directly pins the
percentile-anchored-cutoff behavior so a future change to the band formula
can't silently regress to a fixed-fraction-of-range approach.

This closes the gap because the test exercises exactly the failure
condition (a region whose tone is tightly clustered, not spread evenly)
rather than only images where tone happens to vary smoothly across the
full region.

## Solution

### Immediate Fix
Replaced the fixed-fraction-of-range band formula with percentiles taken
directly from the region's own tone distribution (`np.percentile(region_tone, [85, 55, 20])`,
plus a small `+1.0` epsilon so the strict `<` check in `_hatch_pass`
accepts pixels sitting exactly at a percentile value). This guarantees
each band's cutoff passes close to that fraction of the region's actual
pixels regardless of whether the distribution is flat, skewed, or a real
gradient.

### Long-term Fix
None needed beyond the above.

## Prevention
- [x] Code changes required (percentile-anchored band cutoffs in `_extract_colored_strokes`)
- [x] Regression test added
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- `ATELIER-2026-10-28-touching-color-regions-merge-into-one-wrong-color.md`
- `ATELIER-2026-10-28-noisy-color-region-fragments-into-sparse-coverage.md`
- Report: `reports/ATELIER-2026-10-28-phase-9-expressive-pencil-artistry-engine.md`

## References
- `backend/sketch.py` — `_extract_colored_strokes`
- `backend/test_sketch.py` — `test_a_flat_filled_region_still_gets_hatched_not_left_blank`

---

**Resolved By:** Claude (pair-programming session with tinomupezeni)
**Time to Resolution:** ~45 minutes (required two iterations: outlier-robust min/max, then percentile-anchored cutoffs)
