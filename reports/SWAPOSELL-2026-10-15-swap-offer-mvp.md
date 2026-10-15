# Swap-offer MVP

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Feature / Architecture Decision
**Status:** Completed

## Summary
Implemented the first swap-plus-cash marketplace flow. Authenticated buyers can offer one active listing and an optional cash top-up for a seller's swap-enabled listing; sellers can accept or decline, and buyers can withdraw while the offer is pending. The flow reuses direct messaging for conversation context without marking products sold before settlement.

## Context / Trigger
The listing-level swap availability phase was complete, but buyers had no way to submit an actual proposal. The next MVP phase was intentionally scoped to offer creation and explicit seller decisions, while deferring inspection, payment settlement, product locking, and disputes.

## Scope
Included the `SwapOffer` data model, public UUID API responses, ownership and listing validation, offer status actions, linked conversation summaries, Product Detail offer composition, and Messages offer actions. Automatic valuation, escrow, bundles, and final two-product settlement were excluded because they require a later settlement design.

## Method
Validated the existing product, user, messaging, and order boundaries before adding a separate offer model. Used transaction boundaries and row locks for status actions, checked ownership at the API boundary, reused the existing conversation/message system, and verified Django, migrations, frontend compilation, and diff integrity.

## Decisions & Findings
- A separate `SwapOffer` is safer than forcing a two-product exchange into the existing one-product `Order` model.
- The requested listing must be active and `accepts_swaps`; the offered listing must be active and owned by the proposer.
- Offer status remains authoritative in the offer record; system messages provide visible conversation context.
- Accepted offers do not mark inventory sold yet. Inspection, pickup, payment, and dispute handling remain a later settlement phase.
- Conversation relations must use the registered `modules_messaging` app label.

## Changes Made
- Added `SwapOffer` and its migrations in `backend/swapapp/models.py` and `backend/swapapp/migrations/0008_swapoffer.py` / `0009_swapoffer_indexes.py`.
- Added offer creation/listing and accept/decline/withdraw endpoints in `backend/modules/listings/views.py` and routes in `backend/modules/listings/urls.py`.
- Added public UUID offer serialization in `backend/modules/listings/serializers.py`.
- Added typed frontend client methods in `swappify-social-hub/src/server/Server.tsx`.
- Added the Product Detail Make an Offer modal in `swappify-social-hub/src/components/SwapOfferModal.tsx`.
- Added offer status cards and actions to `swappify-social-hub/src/pages/Messages.tsx`.

## Verification
- `python manage.py check` passed with no issues.
- Swap-offer migrations through `0009_swapoffer_indexes` are applied.
- Frontend `npm run build` passed.
- `git diff --check` passed.
- Docker backend image rebuilt successfully.
- `makemigrations --check --dry-run` reports only pre-existing index-removal drift in `modules_listings` and `swapapp` product/order indexes; no swap-offer model drift remains.

## Follow-ups / Deferred
- Add focused backend API tests for ownership, negative top-up, visibility, authorization, and concurrent acceptance.
- Add Playwright coverage for the buyer-to-seller offer journey.
- Design settlement records for two products, inspection, payment verification, pickup OTP, locking, and disputes.
- Replace system-message summaries with structured offer message payloads when the messaging contract is extended.

## References
- `backend/swapapp/models.py`
- `backend/modules/listings/views.py`
- `swappify-social-hub/src/components/SwapOfferModal.tsx`
- `swappify-social-hub/src/pages/Messages.tsx`
- `SOFTWARE-ENGINEER/Database_and_State/SWAPOSELL-2026-10-15-swap-offer-conversation-app-label.md`

---

**Completed By:** Copilot
**Duration:** Same development session
