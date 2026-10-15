# Amazon-Inspired Marketplace Home

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Type:** Feature implementation / UX architecture  
**Status:** Completed

## Summary
Restructured the Swap-O-Sell root route into a marketplace-first homepage inspired by Amazon's information architecture: utility context, a strong commerce hero, department browsing, curated product rails, and trust signals. The full Feed remains available at `/feed` for deeper browsing and filtering.

## Context / Trigger
The prior root experience opened directly into a generic product feed. The user requested an Amazon homepage review and then asked to implement the recommended improvements in order: homepage structure, reusable rails, backend curated queries, and separation between home discovery and full feed browsing.

## Scope
Included the root route, homepage presentation, curated listing API, location-aware nearby results, category entry points, product rails, and focused validation. The existing Feed route, search experience, checkout/order behavior, and product-card interaction design were preserved.

## Method
Reviewed Amazon's homepage information architecture, inspected Swap-O-Sell's existing Home, Feed, Navbar, ProductCard, and listing API contracts, then implemented the homepage as a live composition over a new non-paginated curated endpoint.

## Decisions & Findings
- The root route now serves `Home`; `/feed` remains the full browsing surface.
- Homepage rails are backed by explicit sections rather than loading one undifferentiated listing page.
- Sections include nearby, open-to-swap, recent, and popular listings.
- Location is optional. Without browser location, the first rail uses popular listings and offers a clear location action.
- Amazon's hierarchy was adapted to Swap-O-Sell's local-marketplace strengths: proximity, seller trust, pickup options, and swap clarity.

## Changes Made
- Added `GET /api/listings/home-sections/` with curated section queries and optional latitude/longitude ranking.
- Added `Server.fetchHomeSections`.
- Rebuilt `Home.tsx` with:
  - Zimbabwe/location utility strip
  - marketplace hero and calls to action
  - department cards
  - reusable product rail rendering
  - nearby, open-to-swap, recent, and popular sections
  - trust signal strip
- Changed `/` to render `Home` while retaining `/feed`.
- Added focused home-section API tests for section composition and location validation.

## Verification
- `docker compose exec -T backend python manage.py test modules.listings.test_search` passed: 4 tests, 1 PostgreSQL-only skip.
- Frontend `npm run build` passed.
- Django system checks passed.
- Curated endpoint returned valid grouped JSON with live data.
- Final frontend Docker image rebuilt and served successfully at `http://localhost:8080/`.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add dedicated pagination/load-more behavior to individual homepage rails if catalog volume grows.
- Add category-specific curated sections based on measured engagement.
- Split the frontend bundle when the existing Vite chunk warning becomes a material load-time concern.

## References
- `swappify-social-hub/src/pages/Home.tsx`
- `swappify-social-hub/src/App.tsx`
- `backend/modules/listings/views.py`
- `backend/modules/listings/test_search.py`
- `backend/modules/listings/urls.py`

---

**Completed By:** Copilot  
**Duration:** One implementation session
