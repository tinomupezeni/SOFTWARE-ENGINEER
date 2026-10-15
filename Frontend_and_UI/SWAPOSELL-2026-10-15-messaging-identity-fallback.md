# Messaging Header Fell Back to Unknown

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The message modal displayed `Unknown` for the conversation participant even though the API returned the user's identity.

## Symptoms
- The modal header showed an `Unknown` avatar/name.
- The conversation API returned `other_participant.full_name`.
- The frontend mapper only checked `first_name` and `username`.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** React messaging modal and conversation state
- **Related Components:** `AuthContext.tsx`, `MessageModal.tsx`, `UserProfileSerializer`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Compared the conversation serializer response fields with the frontend conversation mapper.

### 2. Root Cause Analysis
`UserProfileSerializer` exposes `full_name`, but the frontend selected `first_name || username`. The missing value was then replaced with `Unknown`.

### 3. Key Findings
- API identity data was present.
- The frontend mapping did not use the canonical `full_name` field.
- Conversation-list mapping had the same mismatch.

## Root Cause
The frontend and backend used different preferred name fields without a shared normalization rule.

## Prevention / Rule
**Guardrail:** Normalize API conversation participants through one mapper that prefers `full_name`, then `name`, `first_name`, and `username`, with `Unknown` only as the final fallback.

## Solution

### Immediate Fix
Updated conversation mapping to use `full_name` and equivalent fallbacks.

### Long-term Fix
Extract the participant/conversation adapter into a shared typed API adapter and add a contract test using the serializer response shape.

## Prevention
- [x] Prefer `full_name` in conversation mappings
- [x] Apply the same mapping to new and loaded conversations
- [ ] Add an API contract test for participant display fields

## References
- `swappify-social-hub/src/server/AuthContext.tsx`
- `backend/modules/auth/serializers.py`
- `backend/modules/messaging/serializers.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
