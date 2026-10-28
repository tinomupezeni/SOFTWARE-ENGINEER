# Per-pixel noise fragments a real color region into sparse coverage

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
After fixing hue-based connected-components (see related issue), a large
but naturally noisy flat-colored region (e.g. a photograph's sky or
ground, with ordinary sensor/compression-level per-pixel jitter) got
fragmented into hundreds of tiny below-area-threshold islands, because hue
was quantized from raw, un-denoised pixels. The visible result was sparse,
scattered hatching instead of one coherent colored fill.

## Symptoms
- A synthetic landscape image's sky region, after the hue-quantization fix
  for the previous issue, rendered as scattered light-blue streaks instead
  of a continuous gradient fill.
- Colored-stroke count for that region dropped from ~26,000 (pre any fix,
  one merged-but-wrong-colored blob) to ~7,800 (post hue-fix, fragmented)
  — a ~70% drop explained entirely by fragmentation, not by anything
  intentional.

## Environment Details
- **Server/Host:** local dev (`uvicorn` on 127.0.0.1:8787)
- **Services Affected:** `backend/sketch.py` color-region extraction (Faithful Pencil style)
- **Related Components:** `_extract_colored_strokes`
- **Time First Observed:** 2026-10-28, immediately after fixing the hue-merge issue, during the same cross-category verification pass

## Investigation Steps

### 1. Initial Diagnosis
Compared total/colored stroke counts for the same landscape image before
and after the hue-quantization fix; a large, expected drop pointed at the
hue fix itself as the new source of the regression.

### 2. Root Cause Analysis
Added a synthetic test image with Gaussian noise (`std=4`) over a single
flat BGR fill, matching the landscape's gradient-and-noise character, and
reproduced the same fragmentation directly against `_extract_colored_strokes`.

### 3. Key Findings
- Hue was computed from `cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)` on the
  raw, noisy pixels. Even small (std=4) per-channel noise is enough to
  jitter a pixel's hue across a bin boundary.
- One real, visually uniform region therefore got split across several
  `HUE_BIN_COUNT` bins, and within each bin the surviving pixels formed
  many small, disconnected islands — most falling below
  `MIN_COLOR_REGION_AREA` and being silently dropped.

## Root Cause
Hue/chroma classification ran on raw pixel values, which are never
perfectly flat in a real photograph (sensor noise, JPEG blocking,
compression). The hue-bin fix from the prior issue is correct for
*clean* boundaries between genuinely different colors, but assumed input
pixels within one real color are noise-free, which photographic images
never are.

## Prevention / Rule
**Guardrail:** regression test `test_noisy_large_color_region_does_not_fragment_into_sparse_coverage`
in `backend/test_sketch.py`, asserting a large, deliberately noisy
flat-colored fixture still produces dense (>300) colored strokes rather
than a sparse fragment count. This pins the "classify on denoised pixels"
behavior directly against the specific failure mode (noise-driven
fragmentation), not just against clean synthetic shapes.

This closes the gap because clean synthetic test images (like the
touching-shapes fixture in the sibling issue) would never catch this —
only a noisy fixture exercises the actual failure condition, which is why
this needed its own dedicated test rather than reusing an existing one.

## Solution

### Immediate Fix
Classify hue and chroma on a `cv2.medianBlur(img_bgr, 5)` copy, not the
raw pixels. The actual color sample (`median_bgr`) used for each region's
rendered color still comes from the original, non-blurred image — only
the *grouping* decision (which pixels belong to the same region) uses the
denoised copy.

### Long-term Fix
None needed beyond the above.

## Prevention
- [x] Code changes required (median-blur denoising before hue/chroma classification)
- [x] Regression test added
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- `ATELIER-2026-10-28-touching-color-regions-merge-into-one-wrong-color.md` (the fix for that issue is what exposed this one)
- `ATELIER-2026-10-28-flat-color-region-left-entirely-unhatched.md`
- Report: `reports/ATELIER-2026-10-28-phase-9-expressive-pencil-artistry-engine.md`

## References
- `backend/sketch.py` — `_extract_colored_strokes`
- `backend/test_sketch.py` — `test_noisy_large_color_region_does_not_fragment_into_sparse_coverage`

---

**Resolved By:** Claude (pair-programming session with tinomupezeni)
**Time to Resolution:** ~20 minutes
