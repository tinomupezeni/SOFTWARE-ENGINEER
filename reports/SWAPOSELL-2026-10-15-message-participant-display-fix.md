# Message Participant Display Fix

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Bug Fix / UX Improvement
**Status:** Completed

## Summary
Removed the remaining `Unknown` participant display from seller messaging by prioritizing the known seller name passed from the listing and making the backend participant payload explicit.

## Context / Trigger
The user reported that the message header still showed `U` and `Unknown` after the initial conversation-name mapping fix.

## Scope
Included the messaging header fallback and conversation participant serialization. Browser automation and the legacy standalone Messages page remain deferred.

## Method
Inspected the rendered header fallback chain, identified that `Unknown` was truthy and blocked `recipientName`, then added placeholder-aware selection and an explicit backend `name` field.

## Decisions & Findings
- A literal placeholder is not a valid display name.
- The seller name supplied by the listing is the strongest local context when a conversation response is incomplete.
- The backend now returns both canonical profile fields and a convenient `name` field.

## Changes Made
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
  - Ignores `Unknown` when selecting the header name.
  - Derives the avatar initial from the final display name.
- `backend/modules/messaging/serializers.py`
  - Adds explicit `name` to `other_participant`.

## Verification
- `npm run build` passed.
- Django `manage.py check` passed.
- Docker frontend/backend rebuild completed.
- Frontend health returned HTTP 200.
- API health returned the healthy service response.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add contract tests for participant display-name fallback behavior.
- Remove numeric-ID assumptions from the legacy `Messages.tsx` page.

## References
- `Frontend_and_UI/SWAPOSELL-2026-10-15-unknown-message-participant.md`

---

**Completed By:** Copilot
**Duration:** Same development session
