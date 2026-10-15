# Replace Static Messages Page with Live Conversations

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Refactor / User Journey Fix
**Status:** Completed

## Summary

Replaced the static/demo implementation at `/messages` with a live messaging
surface backed by the shared authenticated conversation state and messaging
API. The page now loads real conversations and messages, supports live sends,
shows product context from conversation data, and presents honest loading,
empty, authentication, and error-compatible states.

## Context / Trigger

The user reported that `http://localhost:8080/messages` was still static.
Investigation found that the page used dummy conversations and messages as
fallbacks, assumed numeric IDs, and constructed local fallback messages when
the API failed.

## Scope

Included the `/messages` page and its integration with existing
`AuthContext` messaging methods. The shared API contracts and backend
messaging endpoints were not changed because they already provided the
required live conversation and message operations.

## Method

Compared the page with the existing normalized messaging state in
`AuthContext`, removed dummy-data dependencies, connected conversation
selection to `loadConversation`, and connected sending to `sendMessage`.
Then verified source references, production compilation, container rebuild,
and local health endpoints.

## Decisions & Findings

- `AuthContext` already normalizes UUID conversation IDs, participant details,
  product previews, and server messages.
- The old page bypassed that state and used `sampleChats`, `sampleMessages`,
  `sampleProducts`, and `sampleUsers`.
- The old page used `parseInt` for conversation and receiver IDs, which was
  incompatible with the UUID public-ID contract.
- Failed requests were presented as successful local demo data, masking
  messaging failures; the new page no longer fabricates conversations or
  sent messages.

## Changes Made

- Rebuilt `swappify-social-hub/src/pages/Messages.tsx` around
  `useAuth().messaging`.
- Added live conversation search by participant, product, and last-message
  text.
- Added live conversation selection and message loading.
- Added live message sending through `sendMessage`.
- Added product name/image context from the conversation serializer.
- Added UUID-safe participant and conversation handling.
- Added explicit signed-out, loading, empty, and no-selection states.
- Added mobile back navigation between conversation list and chat view.

## Verification

- Confirmed no dummy-data imports, `parseInt`, or direct static fallbacks
  remain in `Messages.tsx`.
- `npm run build` passed.
- `git diff --check` passed.
- Frontend Docker image rebuilt successfully.
- `http://localhost:8080/` returned HTTP 200 after the container became ready.
- `http://localhost:8080/api/health/` returned the healthy Swap-O-Sell
  response.

## Follow-ups / Deferred

- Add Playwright coverage for conversation selection, message loading, and
  send failure recovery.
- Add a visible retry action for transient conversation/message API failures
  if the shared messaging state exposes a retry-specific error state.
- Consider real-time refresh via WebSockets or polling for messages received
  while a conversation is open.

## References

- `swappify-social-hub/src/pages/Messages.tsx`
- `swappify-social-hub/src/server/AuthContext.tsx`
- `swappify-social-hub/src/server/api.tsx`

---

**Completed By:** Copilot
**Duration:** One implementation session
