# Guest Messaging Identity

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** UX Fix / Data Contract Hardening
**Status:** Completed

## Summary

Replaced the unhelpful `Unknown` participant label in messaging with a
stable, privacy-preserving guest display name such as `Guest buyer 31cf8c`.
Registered users continue to display their normal name or username.

## Context / Trigger

The messaging UI showed `Unknown` when a conversation participant did not have
a usable full name, username, or profile name. This was especially confusing
for conversations about listings such as `honey meat`, because the recipient
could not be distinguished as a guest participant.

## Scope

Updated conversation serialization and frontend participant normalization.
No account creation, authentication, or database identity fields were changed.

## Method

Traced participant naming from the backend `ConversationSerializer` through
`AuthContext` normalization into both the full Messages page and the direct
message modal. Added a deterministic fallback based on the participant's
public UUID prefix without exposing the full identifier.

## Decisions & Findings

- Prefer `full_name`, display name, first name, and username in that order.
- Treat blank values and the literal `Unknown` as missing identity data.
- Use `Guest buyer <six-character public-ID prefix>` as a stable fallback.
- Use `Guest buyer` when no participant identifier is available.
- Keep the product context separate, so the header remains readable as
  `Guest buyer 31cf8c` and `About: honey meat`.

## Changes Made

- Updated `backend/modules/messaging/serializers.py` to serialize a guest
  fallback name.
- Updated `swappify-social-hub/src/server/AuthContext.tsx` to normalize legacy
  or missing names consistently.
- Updated `swappify-social-hub/src/components/messaging/MessageModal.tsx` to
  avoid rendering `Unknown` in direct messaging.

## Verification

- `npm run build` passed.
- Django system checks passed.
- `git diff --check` passed.
- Confirmed frontend source contains the guest fallback and no static
  `Unknown` participant fallback in `AuthContext`.

## Follow-ups / Deferred

If a formal guest-account model is introduced later, the display fallback can
be replaced with a server-issued guest handle while preserving this UI
contract.

## References

- `backend/modules/messaging/serializers.py`
- `swappify-social-hub/src/server/AuthContext.tsx`
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
- `swappify-social-hub/src/pages/Messages.tsx`

---

**Completed By:** Copilot
**Duration:** One implementation session
