# LEC Biotec — Hero Section Slideshow Carousel Toggle (LEC-090)

**Date:** 2026-11-25  
**Author:** Winston / Assistant  
**Status:** Complete  

## Context / Trigger
On the storefront home page hero section, multiple images can be specified for rotating lab photography (slideshow), or a single background image can be specified. The client requested the capability from the admin editor to toggle the carousel on or off:
- When toggled on, it displays a slideshow cross-fading through the images.
- When toggled off, it displays a single selected image chosen by the admin.

## Scope
- `apps/api/apps/content/sections.py`: Add `show_carousel` boolean field to `HeroContentSerializer` and register field in `SECTION_TYPES["hero"]`.
- `apps/storefront/src/features/marketing/components/HeroSection.tsx`: Support `show_carousel` toggle so that when disabled, it renders the static selected image (fallback to the first slide image if empty) without running a slideshow.
- `apps/storefront/src/features/marketing/components/LightHero.tsx`: Respect `show_carousel` toggle.
- `apps/api/apps/content/tests/test_section_rows.py`: Test `show_carousel` validation and default value.
- `apps/storefront/src/features/marketing/marketing.test.tsx`: Test storefront rendering when `show_carousel` is false.
- Schema & client contract synchronization.

## Verification
- `npm run verify` passed: ESLint, TypeScript check across all workspaces, vitest suites (storefront, admin, ui, api-client), Vite production builds for storefront and admin, secret scan, content gate, and ui-text gate.
- `npm run api:verify` passed: Layering gates, contract check, Ruff lint, Ruff format, Mypy strict check across 191 files, and 1,001 pytest test cases passing with 96.19% code coverage.
