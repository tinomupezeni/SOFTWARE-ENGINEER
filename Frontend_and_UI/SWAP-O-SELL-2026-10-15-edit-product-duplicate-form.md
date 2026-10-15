# Edit Product Rendered as Duplicate Form

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Editing a listing opened a second `UploadProduct` form below the listings
grid while the original product card remained visible. This made edit mode
look like a new listing flow and forced the user to reconcile two separate
representations of the same product.

## Symptoms
- The original product card remained at the top of the profile listings.
- A full edit form appeared later at the bottom of the profile content.
- The edit form was not spatially attached to the product being edited.

## Environment Details
- **Server/Host:** Local development
- **Services Affected:** Frontend profile/listing management
- **Related Components:** `Profile.tsx`, `UploadProduct.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Traced the edit button handler and the conditional rendering of
`UploadProduct` in the profile page.

### 2. Root Cause Analysis
`handleEditProduct` set `editingProduct` and `uploadProduct`, but the form
was rendered in a separate bottom section. The listings grid did not use the
editing state to replace the selected card.

### 3. Key Findings
- Create mode and edit mode shared one boolean presentation path.
- Edit mode was not keyed to a listing's position.
- The selected card and editor were simultaneously mounted.

## Root Cause
The profile page modeled “editor open” but not “replace this listing with its
editor,” so edit presentation was appended rather than attached to the
selected product.

## Prevention / Rule
**Guardrail:** An inline resource editor must render at the resource's
original collection position, while a standalone editor is reserved for
create mode.

This keeps the object being edited spatially associated with its controls and
prevents duplicate editor surfaces.

## Solution

### Immediate Fix
- Replaced the selected product card with `UploadProduct` in the listings
  grid when editing.
- Restricted the standalone bottom `UploadProduct` rendering to create mode.
- Preserved the existing save, refresh, cancel, and edit payload behavior.

### Long-term Fix
Add a browser interaction test that opens edit on a listing and asserts that
only one editor is present and the original listing card is not duplicated.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `swappify-social-hub/src/pages/Profile.tsx`
- `swappify-social-hub/src/pages/UploadProduct.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same implementation session
