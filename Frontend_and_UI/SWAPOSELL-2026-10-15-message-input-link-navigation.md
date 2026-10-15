# Message Input Click Navigated Through Product Card Link

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Clicking the message input from a product-card messaging modal navigated to the product route because the modal was rendered inside the card's React Router link and input events bubbled to the parent link.

## Symptoms
- The Message Seller modal opened.
- Clicking `Type your message...` navigated to the product feed/detail route.
- Users could not reliably enter a message from the card.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** React product card and messaging modal
- **Related Components:** `ProductCard.tsx`, `MessageModal.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the product-card DOM structure and found the modal rendered as a descendant of the card-level `<Link>`.

### 2. Root Cause Analysis
The message button stopped propagation, but the modal input did not. Its click event bubbled to the wrapping product link and triggered navigation.

```bash
npm run build
curl -I http://localhost:8080/
```

### 3. Key Findings
- Product-card navigation is implemented by a parent link.
- The modal contains form controls inside that link subtree.
- Pointer and click events need to be isolated at the modal boundary.

## Root Cause
Interactive modal content was nested inside a navigational anchor without a propagation boundary.

## Prevention / Rule
**Guardrail:** Modal overlays containing forms must stop pointer and click propagation at their root when mounted inside clickable card content, or render through a document-level portal.

This prevents form interaction from activating the card’s navigation target.

## Solution

### Immediate Fix
Added `onClick` and `onPointerDown` propagation guards to the modal loading and content roots.

### Long-term Fix
Move card-level modals to a React portal so interactive dialogs are structurally outside product links.

## Prevention
- [x] Stop modal events from reaching product-card navigation
- [x] Rebuild and serve the updated bundle
- [ ] Render messaging modals through a portal
- [ ] Add browser test asserting input focus does not change the route

## References
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
- `swappify-social-hub/src/components/ProductCard.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
