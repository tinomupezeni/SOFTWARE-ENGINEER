# Product card message action overflowed narrow cards

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Environment:** Development  
**Severity:** Low  
**Status:** Resolved

## Summary
The ProductCard social-action row kept the “Message seller” button inline at all widths. On the narrow two-column homepage cards, the combined social controls and button exceeded the card width.

## Symptoms
- “Message seller” did not fit cleanly inside the card.
- The action row could overflow or compress adjacent social controls on small screens.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** React storefront
- **Related Components:** `swappify-social-hub/src/components/ProductCard.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the ProductCard action row and reproduced the layout condition from the homepage's narrow product grid.

### 2. Root Cause Analysis
The row used `justify-between` without wrapping, while the social controls and fixed-width action label competed for the limited card width.

### 3. Key Findings
- The issue was responsive layout behavior, not a button text or card data problem.
- The action row needed an explicit narrow-screen layout.

## Root Cause
The ProductCard action container did not allow its controls to wrap and the message button had no responsive width strategy.

## Prevention / Rule
**Guardrail:** Responsive card action rows must allow wrapping and provide a full-width narrow-screen fallback for text actions.

This prevents fixed action labels from overflowing cards when the same component is rendered in denser grids.

## Solution

### Immediate Fix
Enabled wrapping on the action row, allowed the social controls to shrink, and made “Message seller” full-width below the `sm` breakpoint while retaining inline behavior on wider cards.

### Long-term Fix
Include narrow-card action layout in visual regression coverage when adding new card actions.

## Prevention
- [x] Responsive layout code updated
- [x] Production build verified
- [ ] Visual regression automation

## References
- `swappify-social-hub/src/components/ProductCard.tsx`

---

**Resolved By:** Copilot  
**Time to Resolution:** One implementation pass
