# Swap-offer API hardening

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Testing / Security Hardening
**Status:** Completed

## Summary
Added focused backend API tests for the swap-offer MVP. The suite now verifies authenticated offer creation, incoming and outgoing visibility, listing ownership and swap eligibility, invalid cash values, duplicate pending offers, and participant-specific accept/withdraw authorization.

## Context / Trigger
The swap-offer MVP had been implemented and manually validated, but its authorization and validation boundaries were not protected by automated regression tests. Because offers transfer trust between two users and reference two listings, these rules needed deterministic coverage before extending the flow into settlement.

## Scope
Included the Django REST API behavior for swap-offer creation, listing, and status actions. Browser E2E coverage, structured offer message payloads, inventory locking, payment settlement, inspection, pickup, and dispute workflows remain outside this phase.

## Method
Created isolated Django `TestCase` fixtures for a seller, buyer, unrelated user, swap-enabled requested listing, and owned offered listing. Each test exercises the public UUID API endpoints through DRF's `APIClient`, then verifies both response contracts and persisted offer state.

## Decisions & Findings
- Public UUIDs are used at the API boundary for both requested and offered products.
- Ownership is enforced server-side; the client cannot choose another user's offered listing.
- Only swap-enabled active requested listings accept offers.
- Only the recipient can accept or decline, and only the proposer can withdraw.
- Duplicate pending offers for the same product pair are rejected.
- The existing messaging conversation creation remains part of successful offer creation.

## Changes Made
- Added `backend/modules/listings/test_swap_offers.py`.
- Kept existing listing/order regression tests isolated in `backend/modules/listings/tests.py`.
- Added four focused tests:
  - Buyer creation and proposer/recipient visibility.
  - Ownership, swap eligibility, same-listing, and negative top-up rejection.
  - Participant authorization and accepted-state behavior.
  - Duplicate pending offer rejection.

## Verification
- `docker compose build backend --quiet` passed.
- `python manage.py test modules.listings.test_swap_offers --verbosity 2` passed.
- Result: 4 tests passed in 8.023 seconds.
- Django system checks passed with no issues.
- All swap-offer migrations through `0009_swapoffer_indexes` applied in the test database.

## Follow-ups / Deferred
- Add concurrent acceptance tests using multiple database connections.
- Add Playwright coverage for Product Detail → Make an Offer → Messages.
- Replace system-message summaries with structured offer message payloads.
- Design the later settlement workflow for inspection, payment, product locking, pickup, and disputes.

## References
- `backend/modules/listings/test_swap_offers.py`
- `backend/modules/listings/views.py`
- `backend/swapapp/models.py`
- `SWAPOSELL-2026-10-15-swap-offer-mvp.md`

---

**Completed By:** Copilot
**Duration:** Same development session
