# Sale & Product Forms: No Search/Type-In on Dropdowns, No Way to Create Categories

**Date:** 2026-09-11
**Project:** CRM Professional
**Environment:** Production (field trial with traders)
**Severity:** High (UX Blocker)
**Status:** Resolved

## Summary
Winston ran a field trial with traders today (Record Sale / Record Product flows). Feedback: the Customer, Product, Variant and Supplier fields were plain HTML `<select>` dropdowns with no search and no way to type — unusable for traders with long product/customer lists. Worse, the Product "Category" field had no visibility into existing categories at all, so a trader had no way to tell what categories already existed or how to add a new one.

## Symptoms
- "Record sale and record product, they have a drop down only. Can a person just type the field too."
- "Ku product add product l can't find a way to add my categories and its visual hard to figure out how to add product."
- Traders abandoning the Add Product flow because the Category field looked like an empty, unexplained text box.

## Root Cause
- `frontend/src/features/sales/components/SaleForm.tsx` and `frontend/src/features/products/components/ProductForm.tsx` used native `<select>` elements for Customer, Product, Variant and Supplier — no typeahead/search, so long lists (100+ products/customers) required scrolling a native picker.
- `Product.category` (`backend/apps/products/models.py`) is a free-text `CharField`. The frontend rendered it as a bare `<Input>` with no visibility into categories that already existed for the org.
- The backend already had everything needed to fix this — `ProductViewSet.categories` action (`GET /api/v1/products/categories/`) and a matching RTK Query hook `useGetProductCategoriesQuery` in `productsApi.ts` — but neither was ever wired into `ProductForm.tsx`. The capability existed and was simply unused.

## Solution

### Immediate Fix
Built a reusable, dependency-free `Combobox` component (`frontend/src/components/Combobox.tsx`) — type-to-filter, keyboard navigation, optional "create new" affordance — and wired it in:
- `ProductForm.tsx`: Category is now a searchable Combobox fed by `useGetProductCategoriesQuery`, with `allowCreate` so typing an unmatched name creates it on save (no new backend endpoint needed since category is just a string field). Supplier converted to a searchable Combobox.
- `SaleForm.tsx`: Customer, Product and Variant pickers converted to searchable Comboboxes.
- Also flattened form-section jargon that traders found confusing ("Refine Catalog" → "Edit Product", "Financial Reconciliation" → "Payment", "Asset" → "Product", etc.), consistent with the plain-language pass already done on the Stock page and Sales metrics.

No new npm dependency was added (avoided `react-select`/similar) to keep the PWA bundle light and the offline service worker's caching behavior unaffected.

## Prevention
- [x] When a backend capability + API hook already exists (like `getProductCategories` here), grep for its usage before building UI — it may already be half-wired.
- [ ] Consider a design-review pass over the remaining native `<select>` usages elsewhere in the app (e.g. Deals, Tasks) for the same long-list-with-no-search problem.

## Verification
Committed as `fbf7a55`. `npm run build` (`tsc -b && vite build`) passes with zero errors after fixing the unrelated tracked/broken `node_modules` issue (see [2026-09-11-tracked-broken-node-modules-blocks-typecheck.md](./2026-09-11-tracked-broken-node-modules-blocks-typecheck.md)), which had been blocking any local build verification. Not yet click-tested in a browser against live data — recommend a quick pass with Winston's trader group before the next field trial.

---

**Resolved By:** Claude Code
**Time to Resolution:** ~1 hour
