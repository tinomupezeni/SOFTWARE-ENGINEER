# Product card share action was not discoverable

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Environment:** Development  
**Severity:** Low  
**Status:** Resolved

## Summary
The ProductCard share action was placed in the lower social-controls row, where it was easy to miss and competed with the card's message action. The share control now appears directly below the bookmark in the product image overlay.

## Symptoms
- Users could not readily find the share action on the product card.
- The lower action row had unnecessary competition between counts, share, and “Message seller.”

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** React storefront
- **Related Components:** `swappify-social-hub/src/components/ProductCard.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the ProductCard image actions and social action row after the share action was reported as missing.

### 2. Root Cause Analysis
The share button existed but was rendered beside the engagement counts near the bottom of the card, rather than with the other image-level actions.

### 3. Key Findings
- Share functionality and the share sheet were already implemented.
- The defect was action placement and discoverability, not missing share logic.

## Root Cause
The share action was grouped with social metrics instead of the bookmark/image controls users scan for product actions.

## Prevention / Rule
**Guardrail:** Product-card image actions such as save and share must remain grouped in a consistent overlay action stack.

This keeps high-value product actions discoverable and prevents lower card rows from becoming overcrowded.

## Solution

### Immediate Fix
Moved the share button beneath the bookmark in the image overlay and removed it from the lower social action row.

### Long-term Fix
Use a shared image-action stack when adding future card-level actions.

## Prevention
- [x] UI placement corrected
- [x] Production build verified
- [ ] Visual regression automation

## References
- `swappify-social-hub/src/components/ProductCard.tsx`

---

**Resolved By:** Copilot  
**Time to Resolution:** One implementation pass
