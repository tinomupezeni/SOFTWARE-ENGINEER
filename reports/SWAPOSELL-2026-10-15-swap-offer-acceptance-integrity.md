# Swap-offer acceptance integrity

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Security Hardening / Data Integrity
**Status:** Completed

## Summary
Hardened swap-offer acceptance so each product can be committed to at most one accepted offer. The endpoint now locks both product rows, checks active inventory under the transaction, and rejects conflicts with a clear HTTP 409 response.

## Context / Trigger
The swap-offer API already validated ownership, swap eligibility, participant authorization, and duplicate pending submissions. Review of the acceptance state transition identified that two independent pending offers could still be accepted against the same listing.

## Scope
Included the acceptance transaction and regression coverage for shared requested or offered listings. Product status changes, inspection, payment, settlement records, and final inventory conversion remain deferred to the settlement phase.

## Method
Reviewed the transaction boundary, added deterministic product-row locking, queried for other accepted offers touching either product, and exercised the conflict through the DRF API test client.

## Decisions & Findings
- Offer-row locking alone does not protect product exclusivity.
- Both product rows are locked before conflict evaluation.
- Product rows are selected in ascending internal ID order to reduce deadlock risk.
- A conflicting accepted offer returns HTTP 409 and leaves the new offer pending.
- Products are not marked sold until the later settlement workflow.

## Changes Made
- Updated `backend/modules/listings/views.py` to lock products and reject accepted-offer conflicts.
- Added `test_acceptance_rejects_listing_already_committed_to_another_offer` in `backend/modules/listings/test_swap_offers.py`.
- Added issue log `SWAPOSELL-2026-10-15-swap-offer-duplicate-acceptance.md`.

## Verification
- Backend image rebuilt successfully.
- Django system checks passed.
- `python manage.py test modules.listings.test_swap_offers --verbosity 2` passed: 5 tests.
- `git diff --check` passed.
- All swap-offer migrations applied in the test database.

## Follow-ups / Deferred
- Add multi-connection concurrency testing against PostgreSQL.
- Introduce explicit settlement/inventory reservation records when the exchange lifecycle is designed.
- Add Playwright coverage for the seller acceptance journey.

## References
- `backend/modules/listings/views.py`
- `backend/modules/listings/test_swap_offers.py`
- `SWAPOSELL-2026-10-15-swap-offer-duplicate-acceptance.md`

---

**Completed By:** Copilot
**Duration:** Same development session
