# Auth Provider Exposes Empty Messaging State

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** High
**Status:** Investigating

## Summary
The React authentication provider maintains messaging state internally but
returns a separate hard-coded empty messaging object from its context value.
Consumers of `useAuth().messaging` therefore cannot observe loaded
conversations, the active conversation, messages, loading state, or errors.

## Symptoms
- Messaging API calls can complete, but components consuming the auth context
  continue to receive empty conversations and messages.
- `loading` and `error` state exposed to consumers remain permanently
  `false` and `null`.

## Environment Details
- **Server/Host:** Local development
- **Services Affected:** Frontend messaging UI
- **Related Components:** `AuthProvider`, messaging pages/components
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Read the auth context state initialization, messaging callbacks, and provider
value construction.

### 2. Root Cause Analysis
`AuthProvider` updates the `messaging` React state through
`setMessaging(...)`, but the provider value does not use that state. Instead,
it constructs a new object containing empty arrays and default flags.

```text
swappify-social-hub/src/server/AuthContext.tsx:104
swappify-social-hub/src/server/AuthContext.tsx:222-460
swappify-social-hub/src/server/AuthContext.tsx:455-461
```

### 3. Key Findings
- `loadConversations`, `loadConversation`, and `sendMessage` all update the
  internal `messaging` state.
- The context value exposes `conversations: []`, `messages: []`,
  `currentConversation: null`, `loading: false`, and `error: null` instead.
- This disconnect affects every consumer using the context-based messaging
  state, even when API requests succeed.

## Root Cause
The provider value was likely left with a temporary compatibility placeholder
after the messaging state was introduced. The returned context object should
reference the provider's `messaging` state variable rather than recreating
empty defaults.

## Prevention / Rule
**Guardrail:** Add a focused frontend test that renders `AuthProvider`, invokes
a messaging state transition, and asserts that `useAuth().messaging` reflects
the updated state.

This catches divergence between provider-owned state and the value exposed to
consumers, which type-checking alone cannot detect.

## Solution

### Immediate Fix
No project code was changed during this read-through. Replace the hard-coded
messaging object in the provider value with the `messaging` state variable.

### Long-term Fix
Keep provider state and exposed context values covered by focused provider
tests, especially when compatibility fields are retained.

## Prevention
- [ ] Replace the placeholder messaging object with the live state.
- [ ] Add an `AuthProvider` messaging-state test.
- [ ] Verify the messages page and message modal against the live context.

## Related Issues
- None recorded.

## References
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/src/server/AuthContext.tsx`

---

**Resolved By:** Unresolved
**Time to Resolution:** N/A
