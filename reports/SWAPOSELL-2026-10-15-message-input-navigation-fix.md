# Message Input Navigation Fix

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Bug Fix / UX Improvement
**Status:** Completed

## Summary
Prevented message input interactions from navigating through product listing containers. Dedicated product links now handle navigation, while seller messaging and its form controls remain outside navigation wrappers.

## Context / Trigger
The user reported that clicking the message input still routed to the product feed/detail page after opening Message Seller.

## Scope
Included the product card, Home listing surface, messaging modal boundary, and local frontend verification. Rendering the modal through a React portal remains deferred.

## Method
Inspected event ownership across `ProductCard`, `MessageModal`, and Home. The first event-boundary fix did not remove all navigation ancestors, so the card wrapper and Home click handler were replaced with dedicated product links.

## Decisions & Findings
- The root issue was navigation ownership, not a messaging API failure.
- Product cards no longer wrap interactive controls in a navigational link.
- Home no longer adds a click-to-navigate handler around the complete product card.

## Changes Made
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
  - Added propagation guards to loading and main modal roots.
- `swappify-social-hub/src/components/ProductCard.tsx`
  - Replaced the outer card link with dedicated image and title links.
- `swappify-social-hub/src/pages/Home.tsx`
  - Removed the outer product-card navigation handler.

## Verification
- `npm run build` passed.
- Docker frontend rebuild completed.
- `http://localhost:8080/` returned HTTP 200.
- `http://localhost:8080/api/health/` returned healthy.
- The served bundle is `index-Dg_MPIM8.js`.
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
