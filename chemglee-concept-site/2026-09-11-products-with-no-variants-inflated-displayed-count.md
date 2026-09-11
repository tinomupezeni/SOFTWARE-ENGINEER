# Products With No Sizes/Variants Counted Toward the Displayed Total But Rendered No Card

**Date:** 2026-09-11
**Project:** chemglee-concept-site
**Environment:** Production + Development
**Severity:** Low
**Status:** Resolved

## Summary
`useProducts()` returned every product from the API (or fallback) verbatim,
including any with an empty `variants` array. A product with no sizes can't
be bought or meaningfully shown on a `ProductCard` (no size/price to render),
but it still counted toward the "N certified bulk-available products" hero
subtitle and each category chip's count — so the displayed number didn't
match the number of cards actually shown on the page.

## Symptoms
- Hero subtitle and category chip counts higher than the number of product
  cards actually rendered.

## Root Cause
No filter on `variants.length` between fetching products and handing them to
the UI — a product record with zero variants was treated the same as any
other for counting purposes, even though nothing downstream could render it.

## Solution
`frontend/src/hooks/useProducts.ts` now filters to `variants.length > 0`
before returning products from the hook, so every count derived from
`products` (hero subtitle, per-category chips) matches what's actually
rendered.

## Prevention
- Not applicable — pure client-side filter, no upstream data contract change
  needed. Worth keeping in mind if a future admin feature allows creating a
  product before its variants/pricing are set.

## References
- `frontend/src/hooks/useProducts.ts`
- Merged via PR #3 (`feat/admin-ux-postgres` → `main`), commit `ec3400c`

---

**Resolved By:** winstonjthinker (PR #3), merged by tinomupezeni
**Time to Resolution:** Same session as discovery
