# Engineering Report: Bulk Product Publishing in Admin

**Date:** 2026-11-25  
**Author:** Staff Software Engineer  
**Project:** LEC BIOTEC (`lec-biotech-ascend`)  
**Task ID:** `0141f85d-eaf1-44eb-b3d2-f77c7dd98891`  

---

## 1. Context & Trigger
Managing a laboratory and biotechnology catalogue requires frequent status transitions (e.g. promoting freshly prepared product records to "Published" or taking seasonal lines offline). Previously, administrators were required to navigate into each individual product editor (`/catalogue/products/:productId`) and toggle publication status one-by-one. A bulk publishing mechanism was requested to allow administrators to select multiple items directly from the catalogue list and publish or unpublish them in a single action.

---

## 2. Scope
- **Backend API:**
  - Route: `POST /api/v1/admin/products/bulk-publish` guarded by `IsEditor`.
  - Serializers for request payload (`product_ids: list[UUID]`, `is_published: bool`) and response payload (`published_ids: list[UUID]`, `failed: list[{ id, name, reason }]`).
  - Service layer logic adhering to domain business rules (refusing to publish products that do not possess at least one active SKU / pack size), reporting per-product failures without aborting valid operations.
  - Audit logging of published/updated transitions for every affected product.
- **API Client:**
  - Regenerated OpenAPI specs and updated `@lec/api-client` with typed `bulkPublishProducts` method.
- **Admin Frontend:**
  - Updated `ProductsScreen.tsx` with row selection checkboxes, header select-all (with indeterminate support), and a bulk action bar for Publishing, Unpublishing, and Clearing selection with loading and feedback states.
- **Verification & Testing:**
  - Django unit tests verifying bulk publishing, unpublishing, SKU requirement validation, and role permissions.
  - Vitest unit tests verifying selection and user interaction on `ProductsScreen.test.tsx`.
  - Passing `npm run verify` and `npm run api:verify`.

---

## 3. Method & Implementation Details
1. **Domain & Service Layer (`apps/api/apps/catalogue/services.py`):**
   - Implemented `bulk_set_published(*, product_ids: list[Any], is_published: bool, actor: User | None = None)`.
   - Fetches products in one query with `deleted_at__isnull=True` and prefetches `skus`.
   - Iterates through target IDs, verifying existence and checking that if `is_published=True`, active pack sizes exist (`product.skus.filter(is_active=True).exists()`).
   - Ineligible products are populated into `failed` with descriptive messages while valid products are updated and recorded in the audit log.
2. **REST View & Routing (`apps/api/apps/catalogue/views.py`, `urls.py`):**
   - Registered `ProductBulkPublishView` under `/api/v1/admin/products/bulk-publish`.
   - Permitted only for editor, admin, and owner roles (`IsEditor`).
3. **Contract Generation:**
   - Ran `npm run contract` to update `apps/api/openapi.yaml` and `packages/api-client/src/schema.d.ts`.
   - Exposed `bulkPublishProducts: (productIds: string[], isPublished: boolean)` on `adminApi`.
4. **Admin UI (`apps/admin/src/features/catalogue/ProductsScreen.tsx`):**
   - Added select column with checkboxes using standard accessible HTML controls.
   - Bulk action bar appears when selection count > 0 with "Publish selected" and "Unpublish selected" actions.
   - Integrated with TanStack React Query mutation, invalidating `["admin", "products"]` on success and displaying detailed feedback.

---

## 4. Verification Evidence
- **Backend Tests:**
  - Ran `test_product_editor.py` including `test_bulk_publish_products_success_and_skips_without_sku` and `test_bulk_unpublish_products`. All passed.
  - Ran `test_every_admin_route_requires_at_least_editor` in `apps/accounts/tests/test_admin_session.py`, confirming the new endpoint satisfies role requirements.
  - Ran `npm run api:verify`: Layering gates, OpenAPI contract check, Ruff linter, Ruff formatting, Mypy types (191 files), and pytest suite (1003 tests passed, 96.18% coverage).
- **Frontend Tests & Build:**
  - Ran `npm run test --workspace @lec/admin -- src/features/catalogue/ProductsScreen.test.tsx`: 5/5 passed.
  - Ran `npm run verify`: ESLint (0 warnings), TypeScript check across all packages, Vitest test suites, production build for storefront and admin, secret scan (583 files passed), content gate and UI text gate passed.

---

## 5. Follow-ups
- Deliver QA instructions for Mutsa (`mutepfamutsa@gmail.com`) on ProjectFlow.
- Proceed to next queued task: `56e38dd0-0af4-4bf6-ad3a-fc011cd4bafe` ("Add Access to Full Product Catalogue").
