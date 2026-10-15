# Swap-offer card details

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** UX Enhancement / API Contract
**Status:** Completed

## Summary
Enriched structured swap-offer messages with both exchanged products' images, prices, and currencies. The Messages page now presents a clear two-column review card showing what the user gives, what they receive, and the cash top-up before any offer action.

## Context / Trigger
Structured offer cards were durable in conversations, but they displayed only product names and the cash amount. Users still had to rely on text to identify the exact listings, which was less reliable for similar products or listings without distinctive names.

## Scope
Included structured offer metadata, serializer query optimization, frontend message typing, and the conversation card UI. Product reservation, settlement, inspection, payment, and dispute workflows remain deferred.

## Method
Extended the existing message serializer contract with public product IDs, names, prices, currencies, and first-image URLs. Prefetched offer product images in both conversation read paths, added API assertions for image propagation, and deployed the updated frontend and backend containers.

## Decisions & Findings
- Offer cards show the offered listing and requested listing side by side.
- Missing images render an explicit `No image` state instead of a broken image.
- Prices are shown as reference context; the cash top-up remains separately identified.
- Product IDs remain public UUIDs at the API boundary.
- Both conversation message endpoints prefetch offer product images to avoid per-message image queries.

## Changes Made
- Extended `swap_offer_data` in `backend/modules/messaging/serializers.py`.
- Added offer-image prefetching in `backend/modules/messaging/views.py`.
- Extended message typing in `swappify-social-hub/src/server/AuthContext.tsx`.
- Added visual offer review cards in `swappify-social-hub/src/pages/Messages.tsx`.
- Added image contract assertions and fixtures in `backend/modules/listings/test_swap_offers.py`.

## Verification
- Django checks passed.
- Five swap-offer API tests passed.
- Frontend `npm run build` passed.
- Backend and frontend Docker images rebuilt successfully.
- `http://localhost:8080/` and proxied `/api/health/` returned successfully.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add Playwright coverage for the full offer journey.
- Add richer seller/product links from each offer card.
- Add explicit settlement records after acceptance.
- Add concurrent PostgreSQL acceptance tests.

## References
- `backend/modules/messaging/serializers.py`
- `backend/modules/messaging/views.py`
- `swappify-social-hub/src/pages/Messages.tsx`
- `backend/modules/listings/test_swap_offers.py`
- `SWAPOSELL-2026-10-15-structured-swap-offer-messages.md`

---

**Completed By:** Copilot
**Duration:** Same development session
