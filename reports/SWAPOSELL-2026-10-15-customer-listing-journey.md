# Customer Listing Journey Improvements

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Refactor / UX Improvement
**Status:** Completed

## Summary
Improved the customer-facing listing journey using the completed e-commerce review: cards now open live detail pages, prices respect the listing currency, empty engagement metrics are hidden, and the primary action clearly identifies the seller conversation.

## Context / Trigger
The listing review found that Swap-O-Sell’s cards had a strong image foundation but lacked a reliable card-to-detail path and exposed implementation noise such as repeated zero counters and USD-only pricing.

## Scope
Included the feed card and product detail integration. Excluded the broader feed filtering contract, browser-level test suite, and re-uploading the previously unrecoverable browser-only images.

## Method
Compared the card and detail components with the live backend serializer contract, normalized API data at the detail boundary, then rebuilt and exercised the Docker-served frontend and health endpoint.

## Decisions & Findings
- A live product card must link to `/product/:id`.
- Detail-page data may retain the existing visual model only when API fields are normalized explicitly.
- Zero-valued engagement indicators are not useful primary listing content and should not compete with price, condition, fulfilment, or seller information.
- Currency is part of the product contract and must not be hard-coded to USD.
- “Message seller” is clearer than the generic “Message” action.

## Changes Made
- `swappify-social-hub/src/components/ProductCard.tsx`
  - Restored product detail navigation.
  - Added currency-aware price formatting with cents.
  - Hid zero-valued engagement counters.
  - Renamed the buyer CTA to `Message seller`.
  - Added an accessible card label and share label.
- `swappify-social-hub/src/pages/ProductDetail.tsx`
  - Fetches live listing details from the API.
  - Maps API image, seller, timestamp, and engagement fields into the existing detail view model.
  - Uses the listing currency for price formatting.

## Verification
- `npm run build` passed.
- `docker compose up --build -d frontend` completed successfully.
- `http://localhost:8080/` returned HTTP 200.
- `http://localhost:8080/api/health/` returned `{"ok": true, "service": "swap-o-sell"}`.
- `git diff --check` passed for the changed frontend files.

## Follow-ups / Deferred
- Add browser-level coverage for live card-to-detail navigation.
- Extract the API-to-view-model adapter for reuse across feed, card, and detail pages.
- Reconcile remaining live API versus demo-data fields in feed filters and related listings.
- Re-upload the affected product photos whose old `blob:` URLs were deleted.

## References
- `Frontend_and_UI/SWAPOSELL-2026-10-15-listing-detail-navigation.md`
- `swappify-social-hub/src/components/ProductCard.tsx`
- `swappify-social-hub/src/pages/ProductDetail.tsx`

---

**Completed By:** Copilot
**Duration:** Same development session
