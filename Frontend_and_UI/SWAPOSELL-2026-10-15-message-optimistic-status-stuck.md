# Sent Messages Remained in Sending State

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Messages sent successfully through the modal remained visible as optimistic messages with a loading indicator.

## Symptoms
- A sent message continued showing the sending spinner.
- The server request completed successfully.
- The temporary message was never removed or marked as sent.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** React messaging modal and auth messaging state
- **Related Components:** `MessageModal.tsx`, `AuthContext.tsx`, messaging views
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Traced the temporary message lifecycle from form submission through `sendMessage`.

### 2. Root Cause Analysis
The modal created a temporary `sending` record and only changed it to `failed` on errors. On success, the server response was added to context, but the temporary record remained in local state forever.

### 3. Key Findings
- Successful sends returned a server message.
- Optimistic state had no success cleanup path.
- The send button also duplicated the form submit handler.

## Root Cause
Optimistic UI state was treated as a fallback but had no reconciliation/removal step after a successful response.

## Prevention / Rule
**Guardrail:** Every optimistic record must have explicit success reconciliation, failure reconciliation, and duplicate-submit protection before the interaction is considered complete.

## Solution

### Immediate Fix
- Remove the temporary message after `sendMessage` resolves.
- Remove the duplicate button-level submit handler.
- Normalize server messages and sender IDs before storing them.

### Long-term Fix
Use a message adapter with server IDs and a reconciliation key, then add an integration test asserting one POST and one final sent message.

## Prevention
- [x] Remove optimistic message on success
- [x] Preserve failed state on error
- [x] Prevent duplicate form submission
- [ ] Add browser-level send/reconciliation coverage

## References
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
- `swappify-social-hub/src/server/AuthContext.tsx`
- `backend/modules/messaging/views.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
