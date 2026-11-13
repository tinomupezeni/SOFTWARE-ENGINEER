# E2E Provisioning Assumed SKU Stock Row

**Date:** 2026-11-13
**Project:** LEC Biotec
**Environment:** Production test environment
**Severity:** Low
**Status:** Workaround Applied

## Summary
The temporary live E2E data provisioning attempt failed after creating the SKU
because the provisioning script assumed every SKU already had a related
`StockItem`, and it also assumed a caller-supplied slug would be retained by
the catalogue service. LEC creates stock rows on first inventory touch and
generates product slugs from the product name, so both assumptions stopped the
test setup from reaching the browser journey.

## Symptoms
- The provisioning command created the temporary users, category, product, and
  SKU, then failed with `Sku has no stock`.
- The requested slug did not match the service-generated slug, so the first
  browser navigation reached a product route without an Add to cart control.
- The authenticated E2E test could not start because stock was not initialized.

## Environment Details
- **Server/Host:** `tino-vps` / `93.127.143.153`
- **Services Affected:** `lec_api` test-data provisioning only
- **Related Components:** `apps.catalogue.services`, `apps.inventory.services`
- **Time First Observed:** 2026-11-13 UTC

## Investigation Steps

### 1. Initial Diagnosis
The remote Django shell failed while reading `sku.stock` after the SKU was
created and published.

### 2. Root Cause Analysis
`apps/inventory/services.py` documents and implements on-demand stock-row
creation through `stock_for`, `receive`, and related services. The temporary
provisioning code bypassed that contract by directly dereferencing the
reverse one-to-one relation. Separately, `catalogue.create_product()` owns slug
generation; the seeder passed a slug-shaped value but later used it as though
it were authoritative.

```bash
docker exec -i lec_api python manage.py shell
```

### 3. Key Findings
- `Sku.stock` is optional until the SKU is first counted or stocked.
- `inventory.receive()` uses `get_or_create()` and writes the required ledger
  movement atomically.
- `catalogue.create_product()` derives the actual slug from the product name.
- The application behavior is intentional; the defect was in the temporary
  provisioning procedure.

## Root Cause
The E2E setup procedure treated a lazily created inventory projection as an
eager catalogue relation and treated a generated catalogue identifier as a
caller-controlled field.

## Prevention / Rule
**Guardrail:** E2E data seeders must use returned model identifiers and
initialize inventory only through `apps.inventory.services`; they must never
reconstruct a slug or dereference `sku.stock` before calling an inventory
service.

The inventory service is the single path that creates the stock head and its
ledger entry, and the returned product object is the source of truth for its
generated slug. Together these boundaries prevent setup scripts from bypassing
the stock consistency contract or navigating to a non-existent product.

## Solution

### Immediate Fix
The failed setup was left unchanged and will be resumed idempotently using the
returned product slug plus `inventory.receive()` to create the stock row and
ledger entry.

### Long-term Fix
Promote the temporary provisioning steps into a checked, reusable E2E fixture
or management command with an explicit inventory-service call and a cleanup
path.

## Prevention
- [ ] Add a reusable production-test fixture or management command
- [ ] Add a preflight check that validates the seeded SKU has a stock head
- [x] Keep the procedure on the inventory service boundary

## Related Issues
- None.

## References
- `apps/api/apps/inventory/services.py`
- `apps/api/apps/catalogue/services.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Workaround applied during E2E setup
