# Swap offer duplicate acceptance could commit inventory twice

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The swap-offer acceptance endpoint checked that both listings were active, but it did not check whether either listing had already been committed to another accepted offer. Multiple offers could therefore be accepted against the same inventory.

## Symptoms
- A seller could accept two pending offers for the same requested listing.
- A buyer's offered listing could be accepted into more than one swap.
- Product status remained active, so the conflict was not visible through inventory state.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Backend swap-offer API
- **Related Components:** `swap_offer_action`, `SwapOffer`, `Product`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the acceptance transaction and existing swap-offer tests after hardening participant authorization.

### 2. Root Cause Analysis
The endpoint locked the offer row but only inspected the current offer's two product statuses. It did not lock the referenced product rows or query accepted offers involving either product.

```bash
docker compose exec -T backend python manage.py test modules.listings.test_swap_offers
```

### 3. Key Findings
- Accepted offers were not treated as inventory commitments.
- The same requested product could be accepted repeatedly.
- Status transitions needed product-row locks to serialize conflicting acceptances.

## Root Cause
Acceptance authorization and active-status validation were implemented, but inventory exclusivity was omitted from the state transition invariant.

## Prevention / Rule
**Guardrail:** An offer acceptance transaction must lock both referenced product rows and reject any other accepted offer involving either product.

This makes accepted offers mutually exclusive at the database transaction boundary and prevents duplicate commitments during concurrent seller actions.

## Solution

### Immediate Fix
Acceptance now locks both product rows in deterministic ID order, verifies they still exist and are active, then rejects any conflicting accepted offer with HTTP 409.

### Long-term Fix
Added a regression test that creates two offers sharing the requested listing, accepts the first, and confirms the second remains pending and is rejected.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Related to the swap-offer MVP and later settlement/inventory-locking work.

## References
- `backend/modules/listings/views.py`
- `backend/modules/listings/test_swap_offers.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
