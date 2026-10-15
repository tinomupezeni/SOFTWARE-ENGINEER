# Message Input Navigation Fix

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Bug Fix / UX Improvement
**Status:** Completed

## Summary
Prevented message input interactions from navigating through the product card link. The messaging modal now captures pointer and click events before they reach the card navigation wrapper.

## Context / Trigger
The user reported that clicking the message input still routed to the product feed/detail page after opening Message Seller.

## Scope
Included the messaging modal event boundary and local frontend verification. Excluded the larger structural cleanup of rendering modal content through a portal.

## Method
Inspected event ownership between `ProductCard` and `MessageModal`, identified bubbling into the parent link, added a modal boundary, and rebuilt the Docker-served frontend.

## Decisions & Findings
- The root issue was event propagation, not a messaging API failure.
- Both pointer-down and click events are stopped to cover focus and activation behavior.
- The card link remains available for clicks outside the modal.

## Changes Made
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
  - Added propagation guards to loading and main modal roots.

## Verification
- `npm run build` passed.
- Docker frontend rebuild completed.
- `http://localhost:8080/` returned HTTP 200.
- `http://localhost:8080/api/health/` returned healthy.
- The served bundle is `index-Ob8Wv3J9.js`.
- `git diff --check` passed.

## Follow-ups / Deferred
- Move modal rendering to a React portal.
- Add browser-level route-preservation coverage for focusing and submitting a message.

## References
- `Frontend_and_UI/SWAPOSELL-2026-10-15-message-input-link-navigation.md`
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`

---

**Completed By:** Copilot
**Duration:** Same development session
