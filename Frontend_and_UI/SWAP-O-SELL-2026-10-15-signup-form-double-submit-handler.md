# Sign-up Form Double Submit Handler

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The sign-up button invoked the submission handler through both the form's
`onSubmit` event and the button's `onClick` event. A single click could
therefore trigger duplicate validation and duplicate registration requests.

## Symptoms
- The sign-up button had `type="submit"` and an `onClick={handleSubmit}` prop.
- The containing form also had `onSubmit={handleSubmit}`.
- Keyboard submission and pointer submission followed different event paths.

## Environment Details
- **Server/Host:** Local development
- **Services Affected:** Frontend authentication UI
- **Related Components:** `swappify-social-hub/src/components/auth/Login.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the sign-up page requested for an e-commerce UX audit and traced the
form submission wiring.

### 2. Root Cause Analysis
Inspected the form and submit button event props.

```bash
rg "onSubmit|onClick|type=\"submit\"" swappify-social-hub/src/components/auth/Login.tsx
```

### 3. Key Findings
- `handleSubmit` was attached to the form's `onSubmit`.
- The same handler was attached to the submit button's `onClick`.
- The button already had `type="submit"`, so the explicit click handler was
  unnecessary and could duplicate the request.

## Root Cause
The form used two event entry points for one submission action instead of
letting the semantic submit event own the workflow.

## Prevention / Rule
**Guardrail:** Submit buttons in React forms must use `type="submit"` without
an `onClick` submission handler; form-level `onSubmit` is the single
submission entry point.

This keeps pointer, keyboard, and assistive-technology submission behavior on
one path and prevents duplicate mutation requests.

## Solution

### Immediate Fix
Removed `onClick={handleSubmit}` from the sign-up submit button and retained
`onSubmit={handleSubmit}` on the form.

### Long-term Fix
Apply the single-submit-entry-point rule during review of future forms and
add a focused interaction test if the authentication UI gains automated
browser coverage.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `swappify-social-hub/src/components/auth/Login.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same implementation session
