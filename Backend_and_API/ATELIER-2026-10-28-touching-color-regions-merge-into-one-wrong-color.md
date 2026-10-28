# Touching color regions of different hues merge into one wrong color

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
In Atelier's "Faithful Pencil" color-preservation pass (`backend/sketch.py`,
`_extract_colored_strokes`), two touching or overlapping shapes of
different colors (e.g. a green ellipse partly covered by a purple
triangle) were grouped into a single connected-component region and
assigned one averaged color, silently dropping one of the two real colors
from the drawing.

## Symptoms
- A synthetic test image with a green ellipse overlapped by a purple
  triangle rendered with the triangle showing the *ellipse's* green color
  instead of its own purple.
- This was only caught by deliberately testing a non-skull "geometric
  shapes" image, added specifically to check for overfitting to the skull
  benchmark (Phase 9 artistic-engine work).

## Environment Details
- **Server/Host:** local dev (`uvicorn` on 127.0.0.1:8787)
- **Services Affected:** `backend/sketch.py` color-region extraction (Faithful Pencil style)
- **Related Components:** `_extract_colored_strokes`
- **Time First Observed:** 2026-10-28, during Phase 9 cross-category verification

## Investigation Steps

### 1. Initial Diagnosis
Direct pipeline call on a synthetic 4-shape image (`image_to_strokes(..., style="faithful")`)
showed only 3 distinct colors across 4 shapes, with the triangle's region
rendering in the ellipse's color.

### 2. Root Cause Analysis
Dumped `cv2.connectedComponentsWithStats` output on the raw CIELAB-chroma
binary mask directly:

```bash
.venv/bin/python3 debug_ellipse.py
```

### 3. Key Findings
- The chroma mask was a single binary "is this pixel colorful" mask with
  no hue information, so `connectedComponentsWithStats` merged the two
  touching shapes into one blob (area=40259, bbox spanning both shapes).
- `_extract_colored_strokes` then computed one `median_bgr`/`hex_color` for
  that whole merged blob and used it for every stroke in it.

## Root Cause
Connected-components ran on a binary chroma mask that only encodes
"colorful vs. not", not hue. Two touching regions of different hues are
therefore indistinguishable from one larger region of a single hue.

## Prevention / Rule
**Guardrail:** regression test `test_touching_differently_colored_regions_both_get_their_own_color`
in `backend/test_sketch.py`, asserting that a two-shapes-overlapping
fixture produces at least one greenish and one purplish stroke color.
This pins the hue-quantization-before-connected-components behavior so a
future refactor of the color-region extraction can't silently reintroduce
single-mask merging.

This closes the gap because the test fails immediately (one color present,
not both) if hue quantization is ever removed from the connected-components
step, rather than only being caught by manual visual inspection of a
specific test image.

## Solution

### Immediate Fix
Quantized hue (from `cv2.COLOR_BGR2HSV`) into `HUE_BIN_COUNT = 12` bins and
ran `connectedComponentsWithStats` separately per hue bin, so two touching
regions of different hue can never merge into one component even though
they're both part of the same binary chroma mask.

### Long-term Fix
None needed beyond the above — the fix is the long-term fix. No
architecture change required.

## Prevention
- [x] Code changes required (hue-bin split in `_extract_colored_strokes`)
- [x] Regression test added
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- `ATELIER-2026-10-28-flat-color-region-left-entirely-unhatched.md`
- `ATELIER-2026-10-28-noisy-color-region-fragments-into-sparse-coverage.md`
- Report: `reports/ATELIER-2026-10-28-phase-9-expressive-pencil-artistry-engine.md`

## References
- `backend/sketch.py` — `_extract_colored_strokes`
- `backend/test_sketch.py` — `test_touching_differently_colored_regions_both_get_their_own_color`

---

**Resolved By:** Claude (pair-programming session with tinomupezeni)
**Time to Resolution:** ~20 minutes (found and fixed within the same verification pass)
