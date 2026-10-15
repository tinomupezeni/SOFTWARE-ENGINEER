# Messaging API Route Prefix Mismatch

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** High
**Status:** Investigating

## Summary
The frontend messaging client builds requests against root API paths such as
`conversations/` and `messages/`, but Django mounts the messaging URL
configuration under `/api/messaging/`. Messaging requests therefore target
routes that are not registered by the backend.

## Symptoms
- Conversation loading, message sending, conversation creation, and read
  status requests can return 404 responses.
- Other API calls use the same `/api/` base URL but do not account for the
  messaging namespace.

## Environment Details
- **Server/Host:** Local development
- **Services Affected:** Frontend/backend messaging integration
- **Related Components:** `Server.tsx`, `swaposell/urls.py`,
  `modules/messaging/urls.py`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Compared the frontend request paths in `Server.tsx` with the Django root URL
configuration and messaging URL configuration.

### 2. Root Cause Analysis
Django includes the messaging routes with the prefix `api/messaging/`, while
the frontend calls paths such as `conversations/`, `messages/`, and
`start-conversation/` directly from the `/api/` base URL.

```text
swappify-social-hub/src/server/Server.tsx:275-303
backend/swaposell/urls.py:39
backend/modules/messaging/urls.py:4-16
```

### 3. Key Findings
- Backend route: `/api/messaging/conversations/`.
- Frontend request: `/api/conversations/`.
- The mismatch affects all methods in the messaging section of `Server.tsx`.

## Root Cause
The backend namespace was introduced or retained without updating the
frontend API client paths, leaving two incompatible route contracts.

## Prevention / Rule
**Guardrail:** Define the messaging API namespace once in the frontend client
and add an integration test that asserts every messaging method resolves to a
registered Django route.

This prevents path-prefix drift between URL inclusion and client request
construction.

## Solution

### Immediate Fix
No project code was changed during this read-through. Update messaging client
paths to include the `messaging/` namespace, or change the backend inclusion
only after confirming all clients and deployments.

### Long-term Fix
Centralize API route prefixes and add contract coverage for high-traffic
feature namespaces.

## Prevention
- [ ] Align all messaging client methods with `/api/messaging/`.
- [ ] Add a route contract or request-mocking test.
- [ ] Verify conversation loading, sending, creation, and read status end to
  end.

## Related Issues
- `Frontend_and_UI/SWAP-O-SELL-2026-10-15-auth-provider-exposes-empty-messaging-state.md`

## References
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/src/server/Server.tsx`
- `/home/shadowe/Projects/swap-o-sell/backend/swaposell/urls.py`
- `/home/shadowe/Projects/swap-o-sell/backend/modules/messaging/urls.py`

---

**Resolved By:** Unresolved
**Time to Resolution:** N/A
