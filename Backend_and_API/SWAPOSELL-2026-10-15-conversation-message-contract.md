# Conversation message endpoint dropped structured offer metadata

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The primary conversation-message GET endpoint returned a hand-built reduced payload instead of the shared `MessageSerializer`. This silently dropped newly added structured swap-offer metadata from messages, preventing the frontend from rendering durable offer cards in the conversation thread.

## Symptoms
- Swap-offer records were created and linked to messages.
- The detailed conversation serializer could expose message metadata.
- The endpoint used by the frontend returned only `id`, `content`, `sender_id`, and `created_at`.
- Offer cards could not be reconstructed from the live conversation payload.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Backend messaging API and Messages UI
- **Related Components:** `conversation_messages`, `MessageSerializer`, `SwapOffer`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Added a regression assertion that a newly created offer's conversation message includes structured offer metadata.

### 2. Root Cause Analysis
Compared the two conversation read paths. `conversation_detail` used `MessageSerializer`, while `conversation_messages` constructed a legacy dictionary manually.

```bash
docker compose exec -T backend python manage.py test modules.listings.test_swap_offers
```

### 3. Key Findings
- The database relation existed and was populated.
- `MessageSerializer` correctly exposed `swap_offer_data`.
- The frontend's actual message-loading route bypassed that serializer.

## Root Cause
Two messaging read endpoints had divergent response contracts. The legacy endpoint's manual projection was not updated when structured offer metadata was introduced.

## Prevention / Rule
**Guardrail:** All message read endpoints must serialize through `MessageSerializer`; manual message dictionaries are prohibited for API responses.

This keeps message contracts consistent across conversation loading paths and ensures new message-linked features cannot be silently omitted from one route.

## Solution

### Immediate Fix
Updated `conversation_messages` to use `MessageSerializer` with the request context and related offer/product data.

### Long-term Fix
Added a swap-offer regression test that verifies the frontend-facing conversation-message endpoint returns the linked offer ID.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Related to the structured swap-offer conversation phase.

## References
- `backend/modules/messaging/views.py`
- `backend/modules/messaging/serializers.py`
- `backend/modules/listings/test_swap_offers.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
