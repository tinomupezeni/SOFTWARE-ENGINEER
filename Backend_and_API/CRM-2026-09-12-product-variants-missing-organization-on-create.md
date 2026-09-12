# Live End-to-End Testing Found: Adding a Product With Variants Always Failed

**Date:** 2026-09-12
**Project:** CRM
**Environment:** Production (restk-vps, `crm.restksolutions.co.zw`)
**Severity:** Critical (a core, recently-worked-on feature was completely broken)
**Status:** Resolved

## Summary
After fixing the Products/Sales/Expenses schema-drift bugs, ran a genuine end-to-end verification against the live production site: registered a throwaway test organization through the real `/api/v1/accounts/register/` endpoint, got a real JWT, and drove every recently-touched flow through actual HTTP calls (not Django-shell shortcuts). Adding a product with any variant (Size/Color) — the exact feature the Sale-with-variant flow depends on — returned `500`.

## Symptoms
- `POST /api/v1/products/` with a non-empty `variants` array → `500 Internal Server Error`.
- Traceback: `django.db.utils.IntegrityError: null value in column "organization_id" of relation "products_productvariant" violates not-null constraint`, raised from `ProductSerializer.create()`.

## Environment Details
- **Server/Host:** `restk-vps`, `crm-backend-1`
- **Services Affected:** `products` app — any product creation that includes variants (the "+ Add Size/Color Variant" UI), and by extension anything downstream that needs real variant data (e.g. testing the Sale-with-variant stock-deduction fix from 2026-09-11)
- **Related Components:** `apps/products/serializers.py::ProductSerializer.create()`

## Investigation Steps

### 1. Initial Diagnosis
Registered a dedicated test org/user via the real API rather than reusing production data, to keep the test fully isolated and safely cleanable afterward:
```bash
curl -X POST https://crm.restksolutions.co.zw/api/v1/accounts/register/ \
  -d '{"organization_name":"E2E Diagnostic Org", "email":"...", "username":"...", "password":"..."}'
```
Then walked the actual user flow: create a plain product (worked), add stock via `/adjust_stock/` (worked), create a product **with variants** → 500.

### 2. Root Cause Analysis
```python
# apps/products/serializers.py, ProductSerializer.create() (before fix)
def create(self, validated_data):
    variants_data = validated_data.pop("variants", [])
    product = Product.objects.create(**validated_data)
    for variant_data in variants_data:
        ProductVariant.objects.create(product=product, **variant_data)  # no organization=
    return product
```
`ProductVariant` extends `TenantBaseModel`, which requires `organization` with no default. Every nested variant create was missing it.

### 3. Key Findings
- This is the same class of bug as [yesterday's quotations fix](../Backend_and_API/CRM-2026-09-11-quotations-feature-completely-broken.md) — a nested-object create that forgot the tenant FK — just in a different app, found this time by actually exercising the feature over HTTP instead of by writing unit tests first.
- There was also no `update()` override on `ProductSerializer` at all, meaning editing an existing product's variants (add one, rename one, remove one) had no defined behavior — DRF's default nested-write handling doesn't support writable nested serializers without an explicit `update()`.
- `ProductVariantSerializer.id` was declared `read_only`, which would have made a correct `update()` impossible to write anyway (no way to match an incoming variant back to an existing one) — had to make `id` writable-but-optional first.

## Root Cause
A straightforward oversight: the nested-object create path for `ProductVariant` never included the required tenant `organization` field, and there was no corresponding update path at all.

## Prevention / Rule
**Guardrail:** Add a pre-commit/CI static check (a small custom AST or regex rule) that fails on any `TenantBaseModel` subclass's `.objects.create(...)` call missing an explicit `organization=` keyword.

This is the second independent instance of the identical "forgot the tenant FK" mistake in two days (quotations, now products) — a one-off manual grep clearly isn't sufficient; a mechanical, always-on check is the guardrail that actually closes this class of bug.

## Solution
- `ProductSerializer.create()`: added `organization=product.organization` to the nested `ProductVariant.objects.create()` call.
- `ProductSerializer.update()`: added, implementing add/edit/remove-by-id semantics for the `variants` list (any variant not present in the incoming payload, by id, is deleted; a new item with no `id` is created; an item with a matching `id` is updated in place).
- `ProductVariantSerializer.id`: changed from `read_only_fields` to an explicit `serializers.IntegerField(required=False)` so it's optional-but-writable, enabling the id-matching above.
- Added `test_create_product_with_variants` and `test_update_product_variants_add_edit_and_remove` to `apps/products/tests/test_views.py`.

Verified in two stages: locally on a scratch Postgres first (130/130 backend tests green), then re-verified live against production itself — created a product with two variants through the real API, gave one variant real stock, recorded a Sale against that variant, and confirmed the *variant's* stock (not the parent product's) decremented correctly. Also spot-checked Dashboard and Quotation-with-formula-item in the same pass — both correct. All test data (a dedicated throwaway org) deleted afterward; confirmed the 9 real production organizations and their existing product/expense counts were untouched.

## Prevention
- [x] Regression tests added for both create-with-variants and update-with-variants.
- [ ] This is the second "missing organization on nested tenant-model create" bug found in two days (quotations, now products) — worth a quick grep across the codebase for any other `SomeTenantModel.objects.create(...)` calls inside a serializer/service that don't explicitly pass `organization=`, rather than waiting to find each one by testing it directly.
- [ ] General lesson reinforced: schema-level audits (yesterday's column-drift sweep) don't catch this class of bug — the columns all existed correctly, the *application code* just never populated one of them. End-to-end testing of each write path is still necessary even after a clean schema audit.

## Related Issues
- [Quotations feature completely broken — same missing-organization pattern](../Backend_and_API/CRM-2026-09-11-quotations-feature-completely-broken.md)
- [Sales/Expenses schema drift, found via the same push to verify everything works](../Database_and_State/CRM-2026-09-12-sales-and-expenses-same-column-drift-as-products.md)

---

**Resolved By:** Claude Code
**Time to Resolution:** ~25 minutes (found via live e2e test, fixed, verified live)
