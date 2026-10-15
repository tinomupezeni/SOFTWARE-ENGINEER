# Public UUIDs and Dynamic Product Detail

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Architecture Decision / Refactor / UX Improvement
**Status:** Completed

## Summary
Introduced durable UUID public identifiers for users and products while retaining integer database primary keys for existing relational integrity. The product detail page now uses the live API exclusively, supports UUID URLs, loads dynamic comments and related products, and supports UUID-based order and messaging inputs.

## Context / Trigger
Product URLs such as `/product/1` exposed sequential identifiers and the detail page still rendered a static demo product model. The requested customer experience required URLs and client-visible identities such as `/product/<uuid>` and a detail page populated from the actual listing API.

## Scope
Included public user/product IDs, listing/detail routes, serializers, comments lookup, order lookup, messaging input resolution, and the React product detail page. Excluded a destructive rewrite of existing integer primary keys and unrelated static-data surfaces outside the product detail journey.

## Method
Applied an expand-and-adopt schema change: add unique UUID columns with generated values, expose those values through serializers, switch public route converters and lookups to UUIDs, then verify the complete frontend/API path in Docker.

## Decisions & Findings
- Internal integer primary keys remain stable so existing foreign keys, comments, orders, likes, saves, and analytics remain intact.
- `public_id` UUIDs are the client/API identity for users and products.
- Product detail no longer falls back to `sampleProducts`; a missing or failed API listing is an explicit loading/not-found state.
- Related products and comments come from backend responses rather than demo arrays.
- Public UUID inputs are resolved to internal rows at backend boundaries for comments, orders, and messaging.
- Opening a detail page uncovered an existing analytics `F()` expression bug; it was fixed and logged separately.

## Changes Made
- `backend/swapapp/models.py`
  - Added unique indexed UUID `public_id` fields to `User` and `Product`.
- `backend/swapapp/migrations/0005_public_uuid_ids.py`
  - Added and backfilled UUID public identifiers.
- `backend/modules/auth/serializers.py`, `auth/urls.py`, `auth/views.py`
  - Exposed UUID user IDs and switched public user routes to UUID converters/lookups.
- `backend/modules/listings/serializers.py`, `urls.py`, `views.py`
  - Exposed UUID product IDs and switched product actions, detail, confirmation, and user-product lookup to UUIDs.
- `backend/modules/comments/serializers.py`, `comments/views.py`
  - Accepted product UUIDs while preserving internal generic-relation integer storage.
- `backend/modules/messaging/serializers.py`
  - Resolved UUID recipient, participant, and product inputs.
- `swappify-social-hub/src/server/Server.tsx`
  - Updated product/user API methods and comment/order payloads to use strings.
- `swappify-social-hub/src/pages/ProductDetail.tsx`
  - Removed static product/comment fallback.
  - Fetches live product, comments, and related products.
  - Renders dynamic seller, image, trust, metadata, and order content.
- `swappify-social-hub/src/components/OrderPanel.tsx`, `ProductCard.tsx`, `CommentsModal.tsx`, `Feed.tsx`, `Profile.tsx`
  - Propagated UUID product IDs through customer actions.

## Verification
- Frontend `npm run build` passed.
- Backend image compiled successfully.
- `docker compose exec -T backend python manage.py check` passed.
- UUID migration is applied in the running database.
- `GET /api/listings/<product-uuid>/` returned the live listing with UUID product and seller IDs.
- `GET /api/comments/?content_type=product&object_id=<product-uuid>` returned successfully.
- `http://localhost:8080/` returned HTTP 200.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add automated API/browser tests for UUID detail navigation, comments, messaging, and order creation.
- Migrate remaining static/demo surfaces such as search and legacy home interactions.
- Replace remaining integer-only internal order/comment IDs only if there is a product requirement to expose those entities publicly.
- Add a centralized API-to-view-model adapter instead of keeping normalization inside the detail page.

## References
- `Backend_and_API/SWAPOSELL-2026-10-15-product-view-analytics-500.md`
- `backend/swapapp/models.py`
- `backend/modules/listings/serializers.py`
- `swappify-social-hub/src/pages/ProductDetail.tsx`

---

**Completed By:** Copilot
**Duration:** Same development session
