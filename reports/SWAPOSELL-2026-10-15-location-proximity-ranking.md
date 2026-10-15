# Location Proximity Ranking for Marketplace Listings

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Architecture Decision / Feature Implementation
**Status:** Completed

## Summary

Implemented privacy-aware proximity ranking so listings with pickup coordinates
are shown closest-first when a buyer shares their browser location. Buyers can
opt in from Feed or Search, while listings without coordinates remain visible
after geolocated listings and the existing newest-first behavior remains the
fallback.

## Context / Trigger

The marketplace needed to prioritize nearby listings without requiring buyers
to search manually by city or depot text. Existing listings stored only free
text locations, so substring matching could not provide reliable distance
ordering.

## Scope

Included nullable pickup-point coordinates, coordinate validation, Haversine
ranking, browser location consent/use, Feed and Search integration, and an
optional seller location capture action. Precise seller coordinates are not
returned in public listing serializers. PostGIS, reverse geocoding, radius
filtering, and automated browser permission tests remain deferred.

## Method

Reviewed the current listing model, API pagination and sorting, Feed/Search
data flow, listing form, and the database, security, HCI, and E2E engineering
guides. Implemented an expand-only nullable schema change, validated all
coordinate inputs at the API boundary, ranked the complete filtered candidate
set before pagination, and verified builds and API behavior in Docker.

## Decisions & Findings

- Store optional `latitude` and `longitude` on `Product` as the pickup or
  inspection point, not as a required residential address.
- Request buyer location through an explicit action (`Use my location`) and
  retain the successful browser result only in session storage.
- Send buyer coordinates as query parameters for ranking; do not persist or
  log them.
- Use a Haversine calculation for the current SQLite-compatible deployment.
- Listings without coordinates are not hidden; they sort after listings with
  calculable distances.
- Invalid or incomplete viewer coordinates return a clear HTTP 400 response.

## Changes Made

- Added nullable pickup coordinates and migration
  `backend/swapapp/migrations/0006_product_coordinates.py`.
- Added coordinate fields and range validation to listing serializers.
- Extended `GET /api/listings/` with `lat` and `lng` ranking inputs.
- Added `src/lib/location.ts` for browser geolocation and session-scoped state.
- Added nearby controls to `Feed.tsx` and `Search.tsx`.
- Added optional pickup-coordinate capture to `UploadProduct.tsx`.
- Extended `Server.fetchProducts()` to accept typed query parameters.

## Verification

- `docker compose build backend --quiet`
- `docker compose exec -T backend python manage.py check`
- `docker compose exec -T backend python manage.py migrate --noinput`
- `npm run build`
- API request without coordinates retained the existing successful response.
- API request with valid coordinates returned HTTP 200.
- API request with invalid coordinates returned HTTP 400.
- Temporary coordinate fixtures verified nearest-first ordering and were
  restored after the check.
- `git diff --check` passed.

## Follow-ups / Deferred

- Add focused Django API tests for ordering, missing coordinates, and bounds.
- Add Playwright coverage for granted, denied, and unavailable geolocation.
- Consider PostGIS/database-native distance queries as listing volume grows.
- Add approximate distance labels only after confirming the product privacy
  policy and coordinate precision.
- Consider a radius filter as a separate, explicit user intent rather than
  making proximity a hard filter.

## References

- `backend/swapapp/models.py`
- `backend/modules/listings/views.py`
- `backend/modules/listings/serializers.py`
- `swappify-social-hub/src/lib/location.ts`
- `swappify-social-hub/src/pages/Feed.tsx`
- `swappify-social-hub/src/pages/Search.tsx`
- `swappify-social-hub/src/pages/UploadProduct.tsx`
- `Principal_Engineer/engineering-guides/6. Database Engineering.md`
- `Principal_Engineer/engineering-guides/7. Software Security Engineering.md`
- `Principal_Engineer/engineering-guides/12. HCI.md`
- `Principal_Engineer/engineering-guides/8. E2E Testing.md`

---

**Completed By:** Copilot
**Duration:** One implementation session
