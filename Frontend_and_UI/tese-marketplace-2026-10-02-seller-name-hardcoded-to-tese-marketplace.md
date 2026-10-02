# Every product card showed "Tese Marketplace" as the seller, discarding the real lister's name

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, customer-store)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
`productMapper.ts`'s `mapRawProductToProduct` hardcoded `const sellerName
= "Tese Marketplace"` unconditionally, discarding whatever `seller_name`
the backend actually returned for every product on the homepage. The
backend was already correct - confirmed via direct DB/API inspection
that farmer-listed products (e.g. "Engine Test Tomatoes") correctly
stored their real lister's business name ("Engine Consolidation Test
Farm") - but the homepage mapper threw it away before it ever reached
the product card.

## Symptoms
- User report, with a pasted homepage screenshot: every single product
  card (avocado, fresh spices, farmer-listed tomatoes, a partner's
  fertilizer listing) showed "Tese Marketplace" as the seller, including
  products that clearly had a real, different lister.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-customer-store`
  container)
- **Services Affected:** Homepage product cards ("Fresh from Local and
  International Farmers" / "Supplies from our Partners" sections)
- **Related Components:**
  `apps/customer-store/src/features/home/utils/productMapper.ts`,
  `apps/customer-store/src/features/home/types/home.types.ts`
- **Time First Observed:** 2026-10-02

## Investigation Steps

### 1. Initial Diagnosis
Dispatched a research agent to trace the data flow rather than guess:
check the backend's `seller_name` assignment logic first (confirmed
correct and already verified working via `create_product`'s business-
name lookup from the seller's `ProviderApplication`), then check the
actual live DB values.

### 2. Root Cause Analysis
```sql
SELECT name, seller_name, farmer_id FROM products;
-- avocado                        | Tese                           | (none - admin-created, correct fallback)
-- fresh spices                   | Tese                           | (none - admin-created, correct fallback)
-- Partner Fertilizer ...         | Partner Business                | set - correct real lister
-- Engine Test Tomatoes           | Engine Consolidation Test Farm  | set - correct real lister
```
Confirmed the backend was sending the right data in every case. Found
`productMapper.ts:16-17` hardcoding the value instead of reading
`item.seller_name` at all - `ProductCard.tsx` itself already had the
correct fallback chain (`product.seller_name || product.seller ||
"Tese Marketplace"`), but by the time data reached it, the mapper had
already overwritten the real value.

### 3. Key Findings
- Two other pages with similar-looking fallback chains
  (`FarmSuppliesPage.tsx`, `ServicesPage.tsx`) were checked and found to
  be correct - they read `seller_name` first and only fall back to
  "Tese Marketplace" when genuinely absent. Only the homepage mapper had
  the hardcoded override.

## Root Cause
`productMapper.ts` was written assuming every product was sold by Tese
directly (a single-seller marketplace design) and never updated once
farmer/supplier self-listing was added - it never read the `seller_name`
field the backend had been correctly sending the whole time.

## Prevention / Rule
**Guardrail:** Any "map raw API data to UI model" function that drops a
field the API response actually contains is a silent data-loss bug -
when adding a new backend field intended to reach the UI (like
`seller_name` when self-listing was built), grep every mapper function
between the API and the component for whether it's actually passed
through, not just whether the component that renders it is correct.

## Solution

### Immediate Fix
```ts
// apps/customer-store/src/features/home/utils/productMapper.ts
const sellerName = item.seller_name || item.seller || "Tese Marketplace";
```
Added `seller_name?: string` to `RawProductData` (`home.types.ts`) since
it wasn't declared on the type at all.

```bash
npx tsc --noEmit                     # clean
pnpm --filter customer-store build   # clean production build
```
Verified in production by fetching the deployed JS bundle directly and
confirming it contains the fixed logic (`e.seller_name||e.seller||"Tese
Marketplace"`), and cross-checking `GET /api/catalog/products` returns
the correct per-product `seller_name` values matching the DB.

### Long-term Fix
None needed - this was a one-line data-loss bug, now fixed.

## Prevention
- [x] Code changes required (done this session)

## References
- `apps/customer-store/src/features/home/utils/productMapper.ts`
- `apps/customer-store/src/features/home/types/home.types.ts`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~20 minutes from report to verified fix in production
