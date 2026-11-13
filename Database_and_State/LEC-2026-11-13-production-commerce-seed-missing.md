# Production Commerce Seed Missing

**Date:** 2026-11-13
**Project:** LEC Biotec
**Environment:** Production
**Severity:** High
**Status:** Workaround Applied

## Summary
The deployed application had no active delivery methods in production. The
catalogue and cart worked, but checkout could not offer a delivery option for a
valid Harare address, so the Place order control remained disabled.

## Symptoms
- `GET /api/v1/checkout/delivery-options?address_id=...` returned an empty
  list with HTTP 200.
- The checkout page displayed “We have no delivery option for that address
  yet” and disabled order placement.
- A fresh production database had not received the commerce seed data.

## Environment Details
- **Server/Host:** `tino-vps` / `93.127.143.153`
- **Services Affected:** `lec_api`, storefront checkout
- **Related Components:** `apps.orders.management.commands.seed_commerce`,
  `apps.orders.checkout`
- **Time First Observed:** 2026-11-13 UTC

## Investigation Steps

### 1. Initial Diagnosis
The authenticated customer journey reached checkout successfully, but no
delivery radio controls were rendered.

### 2. Root Cause Analysis
The checkout selector correctly filters active delivery methods by city and
country. Production contained no delivery-method rows, despite the repository
providing an idempotent `seed_commerce` command specifically to create the
delivery and tax rows required for checkout.

```bash
docker exec lec_api python manage.py seed_commerce
```

### 3. Key Findings
- The API returned a successful empty response rather than an application
  error; the UI correctly blocked order placement.
- The command seeds delivery methods, tax rates, and the VAT setting without
  overwriting admin-edited rows unless `--force` is used.
- The deployment completed migrations and health checks but did not prove
  commerce seed readiness.

## Root Cause
Deployment readiness covered schema and service health but not required
commerce reference data. The production database therefore satisfied the
database schema while remaining unable to complete a checkout.

## Prevention / Rule
**Guardrail:** The release smoke gate must assert that the commerce seed
precondition exists: at least one active delivery method and one applicable tax
rate must be present before production checkout is considered ready.

This catches a green-but-unusable deployment at release time rather than
waiting for a customer journey to discover an empty delivery configuration.

## Solution

### Immediate Fix
Run the idempotent `seed_commerce` command in the production API container and
re-run the authenticated checkout journey.

### Long-term Fix
Add `seed_commerce` and a read-only commerce readiness assertion to the
deployment script or release smoke check. Keep the command non-destructive and
avoid `--force` during normal deployment.

## Prevention
- [ ] Add commerce seed invocation to the deployment gate
- [ ] Add delivery-method and tax-rate readiness checks to production smoke
- [ ] Document that schema migrations alone do not make checkout operational
- [ ] Add a deployment regression test for an empty commerce reference dataset

## Related Issues
- None.

## References
- `apps/api/apps/orders/management/commands/seed_commerce.py`
- `apps/api/apps/orders/checkout.py`
- `apps/api/apps/orders/selectors.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Workaround applied during live E2E verification
