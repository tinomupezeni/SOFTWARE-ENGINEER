# Live Listing Cards Opened a Non-Live Detail View

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
Customer-facing product cards did not navigate to a detail page, and the detail page only searched demo data. Live API listings therefore could not provide a reliable end-to-end browsing journey.

## Symptoms
- Product-card navigation was commented out.
- Live listings could render in the feed but had no working detail destination.
- The detail page used `sampleProducts` and could report “Product not found” for a live listing.
- Currency display was fixed to USD and empty engagement counters added noise.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** React/Vite frontend and Django listing API integration
- **Related Components:** `ProductCard.tsx`, `ProductDetail.tsx`, `Server.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the feed card route, product detail lookup, and listing API response shape.

### 2. Root Cause Analysis
The feed consumed live API products while the detail page retained an earlier demo-data-only implementation. The card route was disabled to avoid exposing that mismatch, leaving the customer journey incomplete.

```bash
npm run build
curl http://localhost:8080/api/health/
```

### 3. Key Findings
- Backend images are objects with `image_url`, while demo images are strings.
- Live products use `name`, `user`, `created_at`, and API engagement fields.
- The detail page expected `title`, `seller`, `postedAt`, and demo engagement fields.
- The card’s price formatter ignored the listing currency.

## Root Cause
The frontend had no adapter between the live listing contract and the older detail-page view model, and navigation was left disabled as a workaround.

## Prevention / Rule
**Guardrail:** Any route opened from a live API entity must have an integration test that renders the entity’s real response shape and asserts the destination does not fall back to demo-only lookup.

This catches contract drift between list cards and detail pages before a navigation workaround becomes permanent.

## Solution

### Immediate Fix
Enabled the product-card link and added live product loading to `ProductDetail.tsx`.

### Long-term Fix
Keep the API-to-view-model normalization centralized and add browser-level coverage for live listing navigation.

## Prevention
- [x] Normalize live API fields before rendering the legacy detail view
- [x] Use listing currency in customer-facing prices
- [ ] Add browser test for live card-to-detail navigation
- [ ] Reconcile remaining feed and detail data contracts

## Related Issues
- Product image persistence issue and fix
- Inline product edit issue and fix

## References
- `swappify-social-hub/src/components/ProductCard.tsx`
- `swappify-social-hub/src/pages/ProductDetail.tsx`
- `backend/modules/listings/serializers.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
