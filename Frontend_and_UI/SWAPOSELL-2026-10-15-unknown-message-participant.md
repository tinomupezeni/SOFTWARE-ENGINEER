# Message Participant Displayed as Unknown

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The messaging header continued to display `U` and `Unknown` when a seller name was available from the listing context.

## Symptoms
- The conversation header showed `Unknown`.
- The avatar fallback showed `U`.
- The participant payload could contain a literal `Unknown` fallback before the listing-provided seller name was considered.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** Messaging modal and conversation serializer
- **Related Components:** `MessageModal.tsx`, `messaging/serializers.py`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the participant mapping and the header rendering fallback order.

### 2. Root Cause Analysis
The UI treated `Unknown` as a valid truthy participant name, so it prevented the known `recipientName` supplied by the listing from being used.

### 3. Key Findings
- The seller context is available when Message Seller is opened from a listing.
- The literal `Unknown` fallback must not outrank that context.
- The backend now emits an explicit `name` field as well as the profile fields.

## Root Cause
Fallback values were not distinguished from real participant names during display selection.

## Prevention / Rule
**Guardrail:** Display adapters must treat placeholder values such as `Unknown` as missing and prefer the originating screen's known entity label before rendering a generic fallback.

## Solution

### Immediate Fix
The modal now ignores a literal `Unknown` conversation name and uses the supplied recipient name. The backend conversation serializer also emits an explicit participant `name`.

### Long-term Fix
Add a messaging contract test covering missing, full-name, username, and listing-context participant names.

## Prevention
- [x] Ignore placeholder participant names in the modal
- [x] Add explicit backend participant name
- [ ] Add API/UI contract coverage

## References
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
- `backend/modules/messaging/serializers.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
