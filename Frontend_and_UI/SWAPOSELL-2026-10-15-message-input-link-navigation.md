# Message Input Click Navigated Through Product Card Link

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Clicking the message input from a product-card messaging modal navigated to the product route because some listing surfaces still wrapped the card in a parent click-to-navigate container. Event guards alone did not remove that navigation ancestor.

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
Inspected the product-card DOM structure and the Home page wrapper. The modal was rendered inside the card tree, while Home also placed the card inside a click-to-navigate `<div>`.

### 2. Root Cause Analysis
The message button stopped propagation, but the modal input could still interact with an ancestor navigation handler on affected surfaces. The card's modal must not be dependent on propagation guards to remain usable.

```bash
npm run build
curl -I http://localhost:8080/
```

### 3. Key Findings
- Product-card navigation was implemented by a parent link and, on Home, an additional parent click handler.
- The modal contains form controls inside that link subtree.
- Pointer and click events need to be isolated at the modal boundary, and navigation must be attached only to dedicated links.

## Root Cause
Interactive modal content was nested in a clickable listing tree, and Home added a second navigation handler around the entire card.

## Prevention / Rule
**Guardrail:** Modal overlays containing forms must stop pointer and click propagation at their root when mounted inside clickable card content, or render through a document-level portal.

This prevents form interaction from activating the card’s navigation target.

## Solution

### Immediate Fix
Removed the card-level `<Link>` wrapper and added dedicated product links for the image and title. Removed Home's outer click-to-navigate wrapper so Message Seller and modal form controls are outside navigation handlers.

### Long-term Fix
Move card-level modals to a React portal so interactive dialogs are structurally outside product links.

## Prevention
- [x] Stop modal events from reaching product-card navigation
- [x] Remove parent navigation wrappers around interactive cards
- [x] Rebuild and serve the updated bundle
- [ ] Render messaging modals through a portal
- [ ] Add browser test asserting input focus does not change the route

## References
- `swappify-social-hub/src/components/messaging/MessageModal.tsx`
- `swappify-social-hub/src/components/ProductCard.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
