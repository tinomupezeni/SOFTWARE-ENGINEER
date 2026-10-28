# Phase 9 — Expressive Pencil Artistry Engine

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Type:** Feature build + artistic-quality audit
**Status:** Completed

## Summary
Rebuilt Atelier's image-to-pencil-drawing pipeline to fix five root causes
of poor artistic fidelity (lost color, over-dark/mechanical shading,
excessive background hatching, lost fine detail, repetitive strokes), and
added a second selectable artistic style ("Graphite Study", B&W) alongside
the original ("Faithful Pencil", color-preserving). Verified against the
project's hand-drawn reference (a pencil-skull portrait) and, separately,
against three deliberately non-skull categories (a synthetic geometric
image, a synthetic landscape, and a real grayscale pencil-portrait photo)
to check for overfitting — which surfaced three further, genuine color-
extraction bugs, all fixed and regression-tested.

## Context / Trigger
User-driven "Phase 9" specification: Atelier's existing output (compared
directly against the original hand-drawn reference the user pointed to at
`images/og.jpeg`, vs. the flawed `images/produced.png`) had no color,
excessive diagonal background hatching, and muddy/mechanical shading. The
spec asked for root-cause analysis, two selectable artistic styles, color
preservation, multi-scale contour recovery, a richer shading vocabulary,
background-overdraw fixes, and generalization testing beyond the single
benchmark image — all while keeping the existing FastAPI + vanilla-JS
architecture and the planner/playback contract unchanged.

## Scope
**Included:** `backend/sketch.py` CV pipeline (color extraction, contour
extraction, hatching, background suppression), `backend/plan_models.py`
and `backend/planner.py` (optional per-stroke color field, backward
compatible), `backend/main.py` (style parameter plumbing + a payload-shape
bug fix), `frontend/js/renderer.js` + `index.html`/`main.js`/`style.css`
(style selector UI, colored-stroke rendering), full backend/frontend test
suites, and cross-category generalization verification.

**Excluded:** no new ML models, no new frontend framework, no change to
the existing planner/scheduling architecture beyond adding the optional
color field — all per the spec's explicit constraints. Photorealistic
color matching was explicitly out of scope; the brief asked for "muted
colored-pencil accents," not literal source-color reproduction.

## Method
Incremental: audit the existing pipeline against the real reference images
first (not synthetic placeholders — found at `images/og.jpeg` and
`images/produced.png` per the user's direction), fix background
overdrawing and contour recovery, add colored-stroke extraction, add the
richer shading vocabulary, then verify via real Playwright/Chrome browser
screenshots of the actual Canvas output at 25/50/75/100% progress (not the
project's own crude Python preview script, which was independently
confirmed to be visually misleading about density/darkness since it uses
overwrite-blending rather than real alpha compositing). After the skull
benchmark passed visual inspection, ran the same pipeline + browser
verification against three additional, deliberately non-skull image
categories specifically to catch overfitting, per the spec's explicit
requirement not to over-tune against a single benchmark.

## Decisions & Findings

### Root causes (pre-Phase-9 pipeline)
1. **Lost color** — the entire pipeline was grayscale-only; no color
   channel was ever analyzed.
2. **Excessive background hatching** — the lightest hatch band used an
   absolute brightness threshold (240) that fired on almost any non-pure-
   white pixel, including legitimately off-white paper.
3. **Lost fine detail** (teeth, eye sockets) — a single fixed Canny
   threshold/blur combination couldn't recover both large structural
   contours and small fine ones at once.
4. **Mechanical, plotter-like hatching** — a single fixed default hatch
   angle (35°) applied uniformly to all flat regions.
5. A crude Python/OpenCV preview script (not the real Canvas renderer) was
   being used to judge "patchiness," producing a misleading impression of
   the real, correctly alpha-blended output.

### New artistic algorithms
- **Dual style selector**: "Faithful Pencil" (default, color-preserving)
  and "Graphite Study" (B&W), both flowing through the identical
  planner/playback architecture — style only changes which strokes
  `sketch.py` generates.
- **Color preservation**: CIELAB-chroma thresholding to find chromatic
  regions, hue-quantized connected-components (12 bins) to keep touching
  differently-colored regions distinct, a muted-color blend toward gray
  (not full saturation), and a compact per-stroke optional `color` field
  (`#rrggbb`) on the existing stroke schema — fully backward compatible
  (key omitted, not null, when absent).
- **Multi-scale contours**: a coarse Canny pass (structural edges) plus a
  separate fine Canny pass (small detail) with independently tuned
  minimum-length floors and separately reserved stroke-count slots.
- **Background-relative hatch ceiling**: computed from the image's own
  90th/10th-percentile tone spread rather than an absolute threshold, with
  a guard (`MIN_BACKGROUND_SPREAD`) that disengages the ceiling entirely
  for uniformly dark/toned images that have no real "paper" to protect.
  Explicitly does not assume a white background.
  **This was also the mechanism the generalization tests had to verify
  does *not* erase a photograph/landscape's own real background.**
- **Seeded angle jitter**: a coarse per-cell random-angle grid (bilinearly
  upsampled) added to the base hatch angle, so direction drifts smoothly
  rather than repeating identically everywhere, while staying fully
  deterministic.
- **Shared local-accumulation cap**: a coarse-grid stroke-density counter
  shared across neutral and colored passes, preventing uncontrolled
  overdraw in any one region regardless of which pass drew there.

### Generalization testing surfaced three further real bugs
Testing the new color-extraction logic against a synthetic geometric
image and a synthetic landscape (not the skull) — specifically to avoid
overfitting — found three genuine, previously-undetected defects, each
documented as its own bug-log entry and fixed with a regression test:
1. Touching regions of different hues merged into one connected component
   and got a single, wrong, averaged color
   (`ATELIER-2026-10-28-touching-color-regions-merge-into-one-wrong-color.md`).
2. A flat-filled region's fixed-fraction tone-band cutoffs could land
   entirely outside where its actual pixels sat, leaving it completely
   unhatched
   (`ATELIER-2026-10-28-flat-color-region-left-entirely-unhatched.md`).
3. The fix for (1), once applied, exposed that ordinary per-pixel image
   noise could fragment one real color region into hundreds of tiny
   islands, most too small to survive, producing sparse scattered
   coverage instead of a solid fill
   (`ATELIER-2026-10-28-noisy-color-region-fragments-into-sparse-coverage.md`).

None of these three would have been caught by testing only against the
skull benchmark — the skull has no large flat-colored regions and no two
touching differently-hued accents, which is exactly the point of the
spec's "don't overfit" requirement.

### A separate payload-shape bug (found via manual curl, not unit tests)
`plan.model_dump(mode="json")` serialized every stroke's optional `color`
field as a literal `"color": null`, not omitted — real payload bloat and
ambiguous for a client checking "does this stroke have a color" by key
presence. Fixed in `backend/main.py` by stripping the key from each
stroke dict when its value is `None`; verified by re-running the same
curl request before/after (payload dropped from 17.41MB to 17.08MB on the
same image) and by a new regression test.

## Changes Made
- `backend/sketch.py` — dual-style color/contour/hatching pipeline
  (see Decisions & Findings above for the full list of mechanisms).
- `backend/plan_models.py` — optional `color: Optional[str]` field on
  `StrokeAnnotation`, hex-format validated, schema version bumped to
  `1.1.0`.
- `backend/planner.py` — `AnnotatedStroke.color` threaded through
  annotation/serialization.
- `backend/main.py` — `style` form/body parameter on both `/api/sketch`
  and `/api/sketch-url`, plus the null-color-key payload fix.
- `frontend/js/renderer.js` — `strokeColor()` renders a stroke's own color
  when present, via translucent layered Canvas marks (not a pasted
  bitmap).
- `frontend/index.html`, `frontend/style.css`, `frontend/main.js` — style
  selector UI (Faithful Pencil / Graphite Study tabs), wired into both the
  upload and URL-import flows.
- `backend/test_sketch.py`, `backend/test_main.py`,
  `frontend/test/renderer.test.js` — new tests for style selection, color
  preservation/muting/region-boundary respect, background suppression,
  multi-scale contour recovery, accumulation bounds, determinism across
  styles, the null-color-key regression, and the three generalization bugs
  above.

## Verification
- **Backend:** 111 tests passed (108 pre-existing + 3 new generalization
  regressions), `pytest -q`.
- **Frontend:** 137 tests passed, `node --test`.
- **Real browser verification** (Playwright driving the system's actual
  Chrome, not a mocked DOM): both styles against the skull reference at
  25/50/75/100% progress, zero page errors; additionally against a
  synthetic geometric-shapes image, a synthetic landscape, and a real
  grayscale portrait photograph (`933300722809696649.jpeg`), zero page
  errors. All screenshots visually inspected directly (not just asserted
  "successful" from passing automated tests), per the spec's explicit
  instruction not to declare artistic success from test results alone.
- Visual inspection confirmed: clean background preserved on all four
  image categories (including non-white-background photos/landscapes),
  fine detail preserved (teeth, eye sockets, hand/glasses detail in the
  portrait photo), red hatband/tie/cross intact and legible (not
  washed out) in Faithful Pencil style, all four shapes in the geometric
  test correctly retain their own distinct color after the hue-merge fix,
  and the landscape's sky/hill/ground regions show full, solid coverage
  after the flat-region and noise-fragmentation fixes.

### Benchmarks (local dev machine, full-resolution inputs)

| Image | Style | Time | Strokes (total / colored) | Payload |
|---|---|---|---|---|
| Skull (`og.jpeg`) | Faithful | 2.19s | 26,039 / 1,152 | 6.08MB |
| Skull (`og.jpeg`) | Graphite | 1.99s | 26,459 / 0 | 6.24MB |
| Geometric (synthetic) | Faithful | 0.91s | 9,349 / 9,336 | 2.45MB |
| Geometric (synthetic) | Graphite | 0.62s | 9,273 / 0 | 2.17MB |
| Landscape (synthetic) | Faithful | 3.60s | 25,164 / 25,152 | 5.91MB |
| Landscape (synthetic) | Graphite | 1.42s | 19,337 / 0 | 4.63MB |
| Portrait photo (grayscale) | Faithful | 1.96s | 24,351 / 0 (no chromatic content) | 5.41MB |
| Portrait photo (grayscale) | Graphite | 1.71s | 24,351 / 0 | 5.41MB |

All runs well within the existing `MAX_HATCH_STROKES = 120,000` safety
backstop; no run approached it.

## Follow-ups / Deferred
- The "crude Python preview script" used for a fast sanity check earlier
  in this phase remains unreliable for judging final darkness/density
  (confirmed, not assumed) — any future visual tuning should go straight
  to real browser Canvas screenshots, as this phase did for all final
  judgments.
- No further generalization categories were tested beyond the four above
  (skull, geometric, landscape, grayscale portrait); a future session
  could add a full-color photograph with multiple distinct skin/clothing
  tones to further stress the hue-bin color-region logic.
- `HUE_BIN_COUNT = 12` and `MIN_COLOR_REGION_AREA = 40` were not
  exhaustively tuned against a wide image corpus; they're known-correct
  for all four tested categories but could need revisiting for images
  with many small, closely-hued accents (e.g. a floral pattern).

## References
- `ATELIER-2026-10-28-touching-color-regions-merge-into-one-wrong-color.md`
- `ATELIER-2026-10-28-flat-color-region-left-entirely-unhatched.md`
- `ATELIER-2026-10-28-noisy-color-region-fragments-into-sparse-coverage.md`
- `backend/sketch.py`, `backend/plan_models.py`, `backend/planner.py`, `backend/main.py`
- `frontend/js/renderer.js`, `frontend/index.html`, `frontend/main.js`, `frontend/style.css`

---

**Completed By:** Claude (pair-programming session with tinomupezeni)
**Duration:** Single extended session (Phase 9 of a multi-phase build)
