# Enable farmer self-listing; remove dead self-listing UI

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, store-api / customer-store)
**Type:** Scope Decision / Cleanup
**Status:** Completed

## Summary
The customer storefront's homepage groups listings into three sections
("Fresh from Local and International Farmers", "Supplies from our
Partners", "Services from our Partners"), but only suppliers and service
providers had a working path to list their own items — farmers had none.
This session added farmer as a first-class self-listing role end to end
(backend role/permission model + the real, already-live self-listing UI),
tightened role-to-listing-type enforcement for all three roles, and removed
~17 files of dead/never-routed self-listing UI code that was calling
nonexistent backend endpoints.

## Context / Trigger
User asked to "allow users across all 3 categories to list on their own,"
pointing at the homepage sections shown above, and asked that the work
follow the Apple HIG design-review skill (`SOFTWARE-ENGINEER/Lessons/apple-design/`)
for the UI. Two research subagents were used to map (a) the apple-design
skill's guidance and (b) the current catalog/auth ownership model before
any code was touched.

## Scope
**Included:**
- Backend role model: add `farmer` role, restrict which `listing_type` each
  self-listing role may create/keep, fix a role-naming bug found along the
  way (see linked bug-log entry).
- Frontend: extend the real, routed self-listing component
  (`PartnerSection.tsx`, reached from the customer profile page) to support
  farmers, with Apple HIG-informed polish (touch targets, aria-labels,
  in-app destructive-action confirmation, clearer labels).
- Deleting confirmed-dead code discovered during the audit.

**Explicitly excluded (deferred, not overlooked):**
- Seed/demo data for farmers/partners/products (homepage sections will
  still render empty on a fresh DB) — user did not select this in scope.
- A dedicated admin-dashboard "Farmers/Partners" management page (only the
  existing generic application-approval queue exists) — not selected in
  scope.
- A full Apple-HIG design-review pass (contrast audit, dark mode, etc.)
  beyond what was touched while rebuilding the listing form — that's a
  separate, explicit review exercise if wanted later.

## Method
1. Forked two research agents in parallel: one to read the apple-design
   skill and its worked example (`ARCHCODE-2026-09-25-*` reports) for
   concrete guidance to apply; one to map the real catalog/auth ownership
   model (roles, `Product.farmer_id`, `listing_type`, route-level
   authorization) and determine whether "farmer"/"partner" was a real
   ownership dimension or just a display label.
2. Confirmed scope with the user via structured questions rather than
   guessing, since the two initial answers (role-naming-only scope, but
   "apply HIG to the listing form now") were contradictory.
3. Before writing any new UI, traced which self-listing surface was
   actually reachable from `App.tsx`'s routes — found `PartnerSection.tsx`
   (via `CustomerProfilePage.tsx`) was the only one hitting real,
   functioning `store-api` endpoints; a second, more elaborate surface
   (`UserProfile.tsx` + ~13 dependent files) was unrouted and called
   endpoints that don't exist in this codebase (Django-REST-style paths,
   never implemented here).
4. Extended the real surface rather than resurrecting the dead one, then
   deleted the dead cluster once confirmed via precise import-grep that
   nothing else referenced it.

## Decisions & Findings
- **Farmer/partner is a real backend ownership dimension**, not just a
  label: `Product.farmer_id` (owner) and `Product.listing_type` (category:
  `product`/`supplier_product`/`service`) are orthogonal columns, and
  `POST/PUT/DELETE /catalog/admin/products` already enforced per-owner
  scoping for non-admins. The actual gap was narrower than it first
  looked: farmers had no role to be granted and no UI to reach the
  already-capable backend.
- **`PartnerSection.tsx` is the live self-listing surface**; `UserProfile.tsx`
  and its ~13 dependents (`ListingForm.tsx`, `ProductUploadForm.tsx`,
  `SupplierUploadForm.tsx`, `ServiceUploadForm.tsx`, `farmerProducts/*`,
  `profileService.tsx`, `servicesService.tsx`, `supplierService.tsx`, four
  hooks) were confirmed dead: not imported from any route, and their
  service layer targeted Django-REST-style endpoints
  (`/products/listings/my-products/`, etc.) that were never implemented in
  this FastAPI backend — only present in MSW test mocks. Verified via
  precise `grep` for actual `import ... from` statements (not just
  substring matches) before deleting.
- **Role enforcement was missing a dimension**: any approved partner
  (supplier or service_provider) could previously create a product under
  *either* `listing_type`, since the route only checked "is this user an
  approved partner," not "is this the listing_type their approval grants."
  Added `ROLE_LISTING_TYPES` mapping and enforced it on create, and blocked
  non-admins from changing `listing_type` on update.
- Found and fixed an unrelated-but-adjacent bug (admin "Sellers" stats
  always zero) while auditing the role-granting path — logged separately,
  see References.

## Changes Made
Backend (`apps/store-api`):
- `app/modules/auth/models/user.py` — added `FARMER` to `RoleType`; updated
  `ProviderApplication.application_type` doc comment.
- `app/modules/catalog/dependencies.py` — added `farmer` to
  `require_partner_or_admin`; added `ROLE_LISTING_TYPES` mapping.
- `app/modules/catalog/routes/catalog.py` — `create_product` now rejects a
  `listing_type` the caller's role(s) don't grant, and sets
  `is_direct_from_farm` based on `listing_type` instead of trusting client
  input; `update_product` blocks non-admins from changing `listing_type`.
- `app/modules/auth/schemas/auth.py` — `ProviderApplicationCreate` docs
  updated to mention `farmer`.
- `app/modules/auth/services/auth_service.py` — role-naming bug fix (see
  linked bug-log entry).

Frontend (`apps/customer-store`):
- `features/customer-profile/components/PartnerSection.tsx` — added farmer
  application option, farmer-specific listing fields (origin farm name,
  harvest date), per-approval listing-type gating, 44px touch targets,
  `aria-label`s on icon-only actions, in-app `AlertDialog` delete
  confirmations replacing native `confirm()`.
- `core/api/index.ts` — removed barrel re-exports of the two deleted dead
  services.
- Deleted (git-tracked, recoverable from history):
  `features/users/pages/UserProfile.tsx`,
  `features/productupload/{ListingForm,ListingsModal,ProductUploadForm,ServiceUploadForm,SupplierUploadForm}.tsx`,
  `features/productupload/farmerProducts/{UploadProduct,EditProduct,ProductFormFields}.tsx`,
  `services/{profileService,servicesService,supplierService}.tsx`,
  `hooks/{useProfile,useProductForm,useServiceForm,useSupplierForm,useCategories}.ts`.

## Verification
- Syntax-checked all 5 edited Python files with `ast.parse` (no `node_modules`
  installed in this environment, so `tsc`/`vitest` could not be run here —
  frontend changes were verified by careful manual re-read of the full
  updated `PartnerSection.tsx`, and by precise import-grep confirming no
  remaining references to any deleted file before removal).
- Confirmed via grep that the only remaining hits for deleted-file names
  were unrelated substring matches (e.g. a local variable named
  `farmerProducts`, unrelated to the deleted `farmerProducts/` directory).

## Follow-ups / Deferred
- Run `pnpm install && pnpm --filter customer-store typecheck` (or
  equivalent) in an environment with dependencies installed, since this
  session had none available.
- Seed demo farmer/partner/product data so the homepage sections aren't
  empty on a fresh DB.
- Consider a dedicated admin-dashboard farmer/partner management page.
- A full Apple-HIG design-review pass over `PartnerSection.tsx` (and the
  rest of customer-store) if a deeper design audit is wanted later.
- Three now-orphaned type-only interfaces (`SupplierUploadFormProps`,
  `ProductUploadFormProps`, `ServiceUploadFormProps` in `types/{supplier,products,services}.ts`)
  were left in place — unused but harmless, out of scope for this pass.

## References
- `Backend_and_API/tese-marketplace-2026-09-28-admin-seller-stats-wrong-role-filter.md`
  (bug found during this initiative)
- `Lessons/apple-design/SKILL.md` and `reports/ARCHCODE-2026-09-25-archcode-frontend-hig-review.md`
  (design guidance applied)
- Key files: `apps/store-api/app/modules/catalog/routes/catalog.py`,
  `apps/store-api/app/modules/catalog/dependencies.py`,
  `apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~1 session (multi-turn, two parallel research subagents + implementation)
