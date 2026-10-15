# Upload Product Form Double Submit Handler

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The upload-product form attached its submit handler to both the form's
`onSubmit` event and the publish button's `onClick` event. A pointer click
could therefore submit a listing twice.

## Symptoms
- The publish button had `type="submit"` and `onClick={(e) => handleSubmit(e)}`.
- The containing form already used `onSubmit={handleSubmit}`.
- A duplicate request could create repeated listing mutations or repeated
  validation feedback.

## Environment Details
- **Server/Host:** Local development
- **Services Affected:** Frontend listing creation/editing
- **Related Components:** `swappify-social-hub/src/pages/UploadProduct.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the upload form while reorganizing its information architecture
against the HCI guide.

### 2. Root Cause Analysis
Reviewed the form and publish button event wiring.

```bash
rg "onSubmit|onClick|type=\"submit\"" swappify-social-hub/src/pages/UploadProduct.tsx
```

### 3. Key Findings
- The form owned the semantic submit event.
- The submit button redundantly invoked the same handler on click.
- Keyboard and pointer submission did not have a single, controlled entry
  point.

## Root Cause
The form submission workflow was implemented twice: once through the native
submit event and once through a button click callback.

## Prevention / Rule
**Guardrail:** Submit buttons must use `type="submit"` without an `onClick`
mutation handler; forms must centralize submission in `onSubmit`.

This prevents duplicate mutation requests and keeps pointer, keyboard, and
assistive-technology submission behavior consistent.

## Solution

### Immediate Fix
Removed the publish button's explicit click handler and retained the form
`onSubmit` handler.

### Long-term Fix
Use the single-submit-entry-point rule for all future listing and checkout
forms, with browser-level duplicate-click coverage when test infrastructure
is added.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `Frontend_and_UI/SWAP-O-SELL-2026-10-15-signup-form-double-submit-handler.md`

## References
- `swappify-social-hub/src/pages/UploadProduct.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same implementation session
