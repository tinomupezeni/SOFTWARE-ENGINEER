# Messaging UUID Contract and Retry Fix

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Bug Fix / Integration Refactor
**Status:** Completed

## Summary
Fixed the Message Seller flow after public UUID adoption by making conversation responses identity-complete and preventing the modal from repeatedly creating conversations when the returned conversation was already available.

## Context / Trigger
The user reported repeated HTTP 400 requests to `POST /api/messaging/conversations/` when messaging a seller. Investigation followed the recent product/user UUID migration.

## Scope
Included product-scoped conversation serialization, UUID resolution in the shortcut endpoint, and frontend conversation initialization/mapping. Excluded a full messaging redesign and migration of internal conversation/message primary keys.

## Method
Traced one seller-message interaction across the React effect, API helper, Django endpoint, serializer, generic product relation, and response mapping. Reproduced the UUID request with an authenticated local API call, then rebuilt and verified the corrected response.

## Decisions & Findings
- Internal conversation IDs remain integers; product and user references exposed to the client are UUIDs.
- Product-scoped conversations must serialize `product_id` as the product public UUID.
- Matching an existing conversation must use the same UUID identity as creation.
- Conversation-list updates should not themselves retrigger conversation creation.

## Changes Made
- `backend/modules/messaging/serializers.py`
  - Added `product_id` to `ConversationSerializer`.
  - Resolved the generic relation’s internal product row to its public UUID.
- `backend/modules/messaging/views.py`
  - Updated shortcut receiver and product lookups to UUID public IDs.
- `swappify-social-hub/src/server/AuthContext.tsx`
  - Preserved the returned product UUID when mapping a new conversation.
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
  - Removed the conversation-list string from initialization dependencies to prevent duplicate creation attempts.

## Verification
- Frontend `npm run build` passed.
- Docker backend/frontend rebuild passed.
- Django system checks passed.
- Authenticated `POST /api/messaging/conversations/` returned HTTP 201.
- The response included the expected product UUID.
- The served frontend references the fresh bundle `index-8BcL2wTb.js`.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add an automated browser test asserting Message Seller results in one conversation creation request.
- Add server-side idempotency or uniqueness for product-scoped buyer/seller conversations.
- Migrate remaining internal messaging entity IDs only if required by the public API.

## References
- `Integrations_and_Auth/SWAPOSELL-2026-10-15-messaging-conversation-retry-loop.md`
- `backend/modules/messaging/serializers.py`
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`

---

**Completed By:** Copilot
**Duration:** Same development session
