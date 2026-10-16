# [TESC] National ID Validation Error Remained After Correction

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Development validation
**Severity:** Low
**Status:** Resolved

## Summary
The institution student dialog retained the National ID validation message
after the user corrected the field. The input handler updated the form value
but did not clear the separate validation-error state.

## Symptoms
- A failed National ID submission displayed an invalid-format message.
- Replacing the invalid value with a valid National ID left the old error visible.
- The corresponding regression test intermittently timed out while waiting for the message to disappear.

## Environment Details
- **Server/Host:** Local institution frontend workspace
- **Services Affected:** Institution student registration dialog
- **Related Components:** `inst/src/components/AddStudentDialog.tsx`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran the full institution Vitest suite after fixing stale required-field fixtures. The National ID test still timed out.

### 2. Root Cause Analysis
`handleInputChange` updated `formData.national_id`, but `nationalIdError` was only changed during submit validation. Correcting the input therefore did not clear the displayed error.

### 3. Key Findings
- The issue was in the component state transition, not the test runner.
- The failure was deterministic when the invalid-to-valid correction path was exercised.
- The same fix improves the live user experience by removing stale feedback immediately.

## Root Cause
The National ID input and its validation-error state were not synchronized.

## Prevention / Rule
**Guardrail:** Input handlers for fields with independently rendered validation state must clear that field's stale error whenever the value changes.

This keeps displayed validation feedback aligned with the current input and prevents corrected values from remaining visually invalid.

## Solution

### Immediate Fix
Cleared `nationalIdError` whenever the `national_id` input changes.

### Long-term Fix
Kept the invalid-to-valid correction assertion in `AddStudentDialog.test.tsx` and required the full institution Vitest suite in CI.

## Verification
```bash
cd inst
npm test -- --run --reporter=dot
npm run build
```

Result: **8 test files passed, 39 tests passed; production build passed**.

---

**Resolved By:** Copilot
**Time to Resolution:** Same validation session
