# Paper hero's slideshow toggle never animated anything

**Date:** 2026-11-26
**Project:** LEC Biotec (lec-biotech-ascend)
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The home hero's `show_carousel` toggle and `slides` field did nothing in
production: the live hero section's `style.ground` is `"paper"`, so it
renders through `LightHero`, which only ever picked one static photograph
(`slideImages[0]` with the toggle on) and never animated, regardless of how
many slides were configured. The ink hero (`InkHero`/`BackgroundCarousel`)
genuinely rotates and was never broken — it is simply not the component
that is live.

## Symptoms
- ProjectFlow task "Fix Slideshow and Background Image Display" (HIGH):
  "the slideshow does not run even when enabled."
- Production `GET /api/v1/pages/home` showed the hero with
  `style.ground: "paper"`, `show_carousel: true`, and six `slides` entries
  — yet the rendered page never changed photograph.

## Environment Details
- **Related Components:** `apps/storefront/src/features/marketing/components/LightHero.tsx`,
  `apps/storefront/src/features/marketing/components/BackgroundCarousel.tsx`,
  `apps/storefront/src/features/marketing/components/HeroSection.tsx`
- **Time First Observed:** 2026-11-26, while investigating a ProjectFlow
  backlog item.

## Investigation Steps

### 1. Initial Diagnosis
Read `HeroSection.tsx`'s `InkHero` branch first — its `slides` selection
and `BackgroundCarousel`'s interval/crossfade logic were correct, and the
backend's `media_referenced_by()` (`apps/api/apps/content/selectors.py`)
already walks into nested list fields like `slides[].media_id` (fixed
previously as LEC-070) — so the obvious suspects were clean.

### 2. Root Cause Analysis
Queried the live API directly (`GET /api/v1/pages/home`) rather than
assuming which hero variant was in use. The home hero's `style.ground` is
`"paper"`, which `HeroSection` routes to `LightHero`, not `InkHero`. Reading
`LightHero.tsx` showed:
```ts
const media = !showCarousel ? (singleImage || slideImages[0]) : (slideImages[0] || singleImage);
```
With the toggle on, this always resolved to `slideImages[0]` — a single,
unchanging value passed straight to a static `<MediaImage>`. There was no
interval, no `BackgroundCarousel`, nothing that could ever animate.

### 3. Key Findings
- `InkHero` and `LightHero` each independently reimplemented the same
  "carousel on/off, with `media_id`/`slides[0]` fallback" decision, and the
  two were never required to agree on behavior — one actually rotates, the
  other only ever changes which single frame is picked once, at render.
- The admin UI side was already correct: a `slides` list field with
  `media_id` sub-fields does render a proper `MediaPicker` per row (schema
  driven off the serializer, `apps/api/apps/content/sections.py:669-705`),
  so this was not a data-entry problem.
- `seed_content.py`'s hero default is `ground: "ink"`, which is why reading
  only the seed defaults (rather than the live published page) would have
  missed this entirely — the production row had since been edited to
  `"paper"` through the admin.

## Root Cause
`LightHero` never had rotation logic at all; it statically picked one
image and the `show_carousel` toggle only changed *which* one, not whether
it animated.

## Prevention / Rule
**Guardrail:** The rotation (interval, in-view/reduced-motion gating,
crossfade) now lives in one shared hook, `useSlideRotation`
(`apps/storefront/src/features/marketing/useSlideRotation.ts`), used by
both `BackgroundCarousel` (ink) and `LightHero` (paper). A future hero
Background cannot silently omit animation the way `LightHero` did, because
adding a new ground means reusing this hook rather than reimplementing
image selection from scratch.

This closes the gap because the two heroes' slide logic can no longer
drift independently — a fix or feature added to the hook reaches every
Background that uses it.

## Solution

### Immediate Fix
Extracted `useSlideRotation` from `BackgroundCarousel.tsx` and used it in
`LightHero.tsx`'s boxed photo, with an `AnimatePresence` crossfade matching
the ink hero's. `show_carousel`/`slides`/`media_id` now operate
independently and symmetrically on both heroes: on, rotate through
`slides` (falling back to `media_id` only when there are no slides); off,
show `media_id` (falling back to the first slide only when there is no
single image). Covered by
`apps/storefront/src/features/marketing/light-hero-carousel.test.tsx`
(rotates with multiple slides, shows the designated image when off, stays
on one frame with only a single slide even with the toggle on). Verified
with `npx vitest run --root apps/storefront light-hero-carousel` (3/3
passed) and `npm run verify` (full gate, green).

### Long-term Fix
None required beyond the shared hook; no further heroes/Backgrounds are
planned that would reintroduce the duplication.

## Prevention
- [x] Code changes required (done)
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
ProjectFlow task "Fix Slideshow and Background Image Display"
(`54d3dd5c-4f54-4921-94b6-35ccedc7f751`), LEC Biotec project.

## References
- `apps/storefront/src/features/marketing/useSlideRotation.ts`
- `apps/storefront/src/features/marketing/components/LightHero.tsx`
- `apps/storefront/src/features/marketing/components/BackgroundCarousel.tsx`
- Commit `ec36c13`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** < 1 hour
