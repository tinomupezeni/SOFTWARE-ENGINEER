# Sellers could create/edit/delete their own product categories - no uniform taxonomy

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, store-api / customer-store)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
`POST/PUT/DELETE /admin/categories` was gated by `require_partner_or_admin`,
the same dependency used for regular seller-facing catalog routes - meaning
any user holding a `farmer`/`supplier`/`service_provider` role could create,
rename, or delete categories, not just admins. `customer-store`'s
`PartnerSection.tsx` exposed this directly with an "Add Category" button
and a Categories management tab. User feedback, verbatim: "categories
those should be managed by admins right for uniformity across all users."

## Symptoms
- Not an incident - a design review request from the user after seeing the
  self-service listing UI. No user-facing error, but the intended design
  ("uniform taxonomy across sellers") was silently violated: nothing
  stopped two sellers from creating near-duplicate categories (e.g.
  "Veggies" vs "Vegetables"), fragmenting search/browse for buyers.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-store-api` +
  `tese-customer-store` containers)
- **Services Affected:** Category creation/edit/delete across the catalog
- **Related Components:**
  `apps/store-api/app/modules/catalog/routes/catalog.py`,
  `apps/store-api/app/modules/catalog/dependencies.py`,
  `apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`
- **Time First Observed:** 2026-09-28, user review of the self-service
  listing feature shipped earlier the same session

## Investigation Steps

### 1. Initial Diagnosis
Read the actual `/admin/categories` route handlers in
`catalog.py` to check who could call them, rather than assuming from the
route's `/admin/` prefix that it was already admin-only.

### 2. Root Cause Analysis
Found all three write routes (`create_category`, `update_category`,
`delete_category`) using `Depends(require_partner_or_admin)` -
`apps/store-api/app/modules/catalog/dependencies.py:12` defines that as
`require_roles(["admin", "super_admin", "farmer", "supplier",
"service_provider"], get_auth)`, the same list used to gate product
listing routes. `require_admin` (line 11, `["admin", "super_admin"]`) was
already defined and imported into `catalog.py` but never used for the
category write routes - only for other admin-only endpoints elsewhere in
the file.

### 3. Key Findings
- Backend authorization, not just frontend UI, allowed any seller to
  write categories - removing the "Add Category" button from
  `PartnerSection.tsx` alone would not have closed this; a seller could
  still `POST /admin/categories` directly.
- `admin-dashboard` already has category creation UI
  (`AddCategoryModal.tsx`) calling the same endpoint, so admins retain a
  working path once the seller-side write access is removed - confirmed
  before changing the dependency, to avoid breaking the only other
  category-creation UI in the process.
- `GET /admin/categories` (list, including inactive) intentionally stayed
  on `require_partner_or_admin` - sellers still need to read the category
  list to populate their product form's category picker; only the writes
  needed narrowing.

## Root Cause
The category write routes were scaffolded by copy-pasting the dependency
used for the surrounding product-listing routes (`require_partner_or_admin`)
rather than the narrower `require_admin` that was already defined and in
use elsewhere in the same file for actually-admin-only operations.

## Prevention / Rule
**Guardrail:** When adding a new route to `catalog.py` (or any router with
both `require_admin` and `require_partner_or_admin` available), the choice
of dependency must be justified by "does this action need to be uniform
across all sellers" (→ `require_admin`) vs. "does this action only affect
the calling seller's own data" (→ `require_partner_or_admin`) - not by
copying whichever dependency the nearest existing route happens to use.

Categories are shared/global state (every seller's products reference the
same list), so they fail the "own data" test and should never have used
the seller-inclusive dependency; a code-review checklist item asking this
question for any new `/admin/*` route would have caught it at review time
instead of at a later product review.

## Solution

### Immediate Fix
Backend (`apps/store-api/app/modules/catalog/routes/catalog.py`):
- `create_category`, `update_category`, `delete_category` now use
  `Depends(require_admin)` instead of `Depends(require_partner_or_admin)`.
  `GET /admin/categories` (list) unchanged - still readable by sellers.

Frontend (`apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`):
- Removed the seller-facing category management entirely: "Add Category"
  button, the Categories management tab, `saveCategoryMutation`/
  `deleteCategoryMutation`, the category form and its delete-confirmation
  dialog. The categories `useQuery` stayed, now read-only, to populate the
  product form's category `<select>`.

```bash
python3 -m py_compile app/modules/catalog/routes/catalog.py   # clean
npx tsc --noEmit                                              # clean
pnpm --filter customer-store build                            # clean production build
```
Verified in production after redeploy: site and
`GET /api/catalog/categories` both return 200, `store-api` container logs
show clean startup with no errors.

### Long-term Fix
None needed - this was a scoping fix, not a structural one. Worth noting
for future review: `admin-dashboard` has no edit/delete UI for categories
yet (only create) - out of scope for this change, flagged as a gap if an
admin needs to fix a bad category name without going to the database.

## Prevention
- [x] Code changes required (done this session)
- [ ] Add an admin-dashboard UI for editing/deleting existing categories
      (currently create-only)

## Related Issues
- Same session as `Frontend_and_UI/tese-marketplace-2026-09-28-selling-entry-point-undiscoverable.md`
  (the profile-page discoverability fix that preceded this review)

## References
- `apps/store-api/app/modules/catalog/routes/catalog.py`
- `apps/store-api/app/modules/catalog/dependencies.py`
- `apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`
- `apps/admin-dashboard/src/components/AddCategoryModal.tsx` (the retained
  admin-side creation path)

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~20 minutes from request to verified fix in production
