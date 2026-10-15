# Listing Swap Availability

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Feature Slice / UX Improvement
**Status:** Completed

## Summary

Added a listing-level swap availability signal. Sellers can mark a product
as **Open to swaps** and describe the products or categories they would
consider. Buyers see that signal directly on listing cards and in the product
detail view before opening a conversation.

## Context / Trigger

The planned swap-plus-cash flow needs early buyer visibility. A buyer should
know from the listing itself whether a seller is open to a swap and what kind
of item may be acceptable, rather than discovering this only after messaging.

## Scope

Included persistent listing fields, seller form controls, API serialization,
card presentation, and product-detail presentation. The actual swap offer,
counteroffer, acceptance, and settlement workflow is intentionally deferred
to the next feature slice.

## Method

Traced the Product model through create/update serializers, the progressive
disclosure listing form, ProductCard, and ProductDetail. Added optional
backward-compatible fields with a default-off state, then verified backend
migrations, frontend compilation, Docker deployment, and health endpoints.

## Decisions & Findings

- `accepts_swaps` defaults to `false`, preserving existing listing behavior.
- `swap_preferences` is optional free text capped at 500 characters so sellers
  can describe categories, specific items, and cash-top-up expectations.
- Swap controls are placed under Optional details to avoid adding required
  cognitive load to cash-only sellers.
- Cards show a compact `Open to swaps` badge and preference summary.
- Product detail shows a more explanatory panel:
  `Seller may consider another product plus a cash top-up` when no preference
  text was entered.
- No automatic product valuation or automatic acceptance was introduced.

## Changes Made

- Added `Product.accepts_swaps` and `Product.swap_preferences`.
- Added migration `backend/swapapp/migrations/0007_product_swap_preferences.py`.
- Exposed fields through list, detail, create, and update serializers.
- Added seller controls to `UploadProduct.tsx`.
- Added swap badge and preference summary to `ProductCard.tsx`.
- Added swap information panel to `ProductDetail.tsx`.
- Extended the frontend Product type with optional swap fields.

## Verification

- Django system checks passed.
- Migration `swapapp.0007_product_swap_preferences` is applied.
- Frontend `npm run build` passed.
- `git diff --check` passed.
- Frontend Docker image rebuilt successfully.
- `http://localhost:8080/` returned HTTP 200.
- `http://localhost:8080/api/health/` returned the healthy service response.

## Follow-ups / Deferred

- Implement the authenticated swap-offer model and API.
- Add `Make an offer` to swap-enabled product details.
- Render structured swap-offer cards inside Messages.
- Add accept, decline, counteroffer, expiry, product locking, inspection, and
  settlement behavior.
- Add filters for listings open to swaps.
- Add focused API and Playwright tests for the swap signal and offer journey.

## References

- `backend/swapapp/models.py`
- `backend/swapapp/migrations/0007_product_swap_preferences.py`
- `backend/modules/listings/serializers.py`
- `swappify-social-hub/src/pages/UploadProduct.tsx`
- `swappify-social-hub/src/components/ProductCard.tsx`
- `swappify-social-hub/src/pages/ProductDetail.tsx`

---

**Completed By:** Copilot
**Duration:** One implementation session
