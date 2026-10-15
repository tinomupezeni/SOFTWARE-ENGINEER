# Structured swap-offer messages

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Feature / API Contract Hardening
**Status:** Completed

## Summary
Made swap offers durable in conversation threads by linking offer records directly to system messages and exposing structured offer metadata through the messaging API. The Messages page now renders offer cards from the conversation payload and refreshes the thread after accept, decline, or withdraw actions.

## Context / Trigger
The initial swap-offer UI fetched offers separately and displayed plain-text system summaries. That made the offer card dependent on a second request and left the message contract unable to describe the offer itself.

## Scope
Included the message-to-offer relation, serializer contract, frontend message normalization, offer-card rendering, and action refresh behavior. Settlement, inventory conversion, payment, inspection, and dispute workflows remain deferred.

## Method
Added a nullable foreign key from messages to swap offers, reused the existing message serializer, updated the frontend's live message type, and verified the actual conversation-message endpoint with an API regression test.

## Decisions & Findings
- `Message.swap_offer` is nullable so existing text, image, product-share, and system messages remain compatible.
- Offer metadata is returned as `swap_offer_data` with public UUIDs and product summaries.
- The Messages UI renders structured offer cards from the selected conversation, rather than relying on a separate offer list for display.
- After a status action, the current conversation reloads so the card reflects the authoritative server status.
- All message read paths must use the shared serializer; a legacy reduced payload was found and fixed.

## Changes Made
- Added `Message.swap_offer` and migration `backend/modules/messaging/migrations/0002_message_swap_offer.py`.
- Added `swap_offer_data` to `backend/modules/messaging/serializers.py`.
- Updated offer creation and status actions to link system messages to the offer.
- Updated `conversation_messages` to return the shared serialized message contract.
- Updated `AuthContext.tsx` and `Messages.tsx` for structured offer metadata and action refresh.
- Added regression coverage in `backend/modules/listings/test_swap_offers.py`.

## Verification
- Backend image rebuilt successfully.
- Django checks passed.
- Messaging migration `modules_messaging.0002_message_swap_offer` applied.
- Five swap-offer API tests passed.
- Frontend `npm run build` passed.
- Frontend container rebuilt successfully.
- `http://localhost:8080/` and proxied `/api/health/` returned successfully.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add Playwright coverage for the full buyer-to-seller offer journey.
- Add concurrent PostgreSQL acceptance testing.
- Add product images and richer structured offer previews to the offer card.
- Design settlement records and inventory conversion after seller acceptance.

## References
- `backend/modules/messaging/models.py`
- `backend/modules/messaging/serializers.py`
- `backend/modules/messaging/views.py`
- `swappify-social-hub/src/pages/Messages.tsx`
- `SWAPOSELL-2026-10-15-conversation-message-contract.md`

---

**Completed By:** Copilot
**Duration:** Same development session
