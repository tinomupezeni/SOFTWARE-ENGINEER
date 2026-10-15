# Sent Message Disappeared and Product Preview Was Empty

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Messages sent from the modal disappeared after the request completed, and the conversation product preview showed `No Image`.

## Symptoms
- A newly sent message vanished from the active thread.
- The product preview displayed `No Image`.
- Product preview spacing was visually uneven.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** Messaging modal, messaging API contract
- **Related Components:** `MessageModal.tsx`, `AuthContext.tsx`, `messaging/serializers.py`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Traced optimistic message state, server response handling, and conversation serializer fields.

### 2. Root Cause Analysis
The temporary message was removed immediately after sending, while the active message state could lag behind the context update. Separately, conversation responses did not include the product image, and the frontend did not pass the listing image into the modal.

### 3. Key Findings
- The server response contains the authoritative message.
- Optimistic state needs replacement/reconciliation, not immediate deletion.
- Conversation serializers had product IDs but no product image/name fields.

## Root Cause
The messaging UI lacked a stable reconciliation path for the server-created message and an explicit product-preview payload.

## Prevention / Rule
**Guardrail:** Optimistic records must be replaced by the server record using the server ID, and every conversation product preview must expose its image URL in the API contract.

## Solution

### Immediate Fix
- Replace the temporary message with the returned server message.
- Deduplicate server and optimistic messages by ID.
- Add product name/image fields to conversation responses.
- Pass product images from card/detail surfaces.
- Tighten product preview padding and spacing.

### Long-term Fix
Add browser coverage for message persistence and product-preview rendering.

## Prevention
- [x] Reconcile sent messages with server IDs
- [x] Deduplicate merged message state
- [x] Return product image in conversation data
- [x] Pass product image from listing surfaces
- [ ] Add browser-level messaging coverage

## References
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
- `swappify-social-hub/src/server/AuthContext.tsx`
- `backend/modules/messaging/serializers.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
