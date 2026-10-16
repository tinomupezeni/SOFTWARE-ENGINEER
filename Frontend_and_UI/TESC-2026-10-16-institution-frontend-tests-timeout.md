# [TESC] Institution Frontend Student Dialog Tests Time Out

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Development validation
**Severity:** Medium
**Status:** Investigating

## Summary
The institution frontend production build passed, but the Vitest suite had 7 failures, all timeouts in `src/components/AddStudentDialog.test.tsx`. The remaining 32 tests across the suite passed.

## Symptoms
- `npm run build` completed successfully.
- `npm test -- --run` reported 7 failed and 32 passed tests.
- Timed-out cases covered validation, successful creation, API failure, server validation, loading state, and reset behavior.
- Tests emitted repeated React `act(...)` warnings.

## Environment Details
- **Server/Host:** Local institution frontend workspace
- **Services Affected:** Frontend test validation
- **Related Components:** `inst/src/components/AddStudentDialog.test.tsx`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Installed the declared `inst` dependencies and ran the frontend test suite.

### 2. Root Cause Analysis
The failing tests consistently timed out inside the AddStudentDialog interaction flow, while API, auth, hook, and other component tests passed. The exact interaction synchronization defect was not changed during this bulk-upload verification session.

### 3. Key Findings
- 7 of 39 tests failed.
- 32 tests passed.
- Failures are isolated to AddStudentDialog tests.
- The production bundle builds successfully.

## Root Cause
Not yet isolated; likely test interaction synchronization or component state handling around dialog rendering and submission.

## Prevention / Rule
**Guardrail:** Require the institution frontend Vitest suite to pass in CI, with dialog tests using explicit `waitFor`/`act` synchronization around asynchronous state changes.

This prevents UI upload and data-entry regressions from being hidden by a green production build alone.

## Solution

### Immediate Fix
No application change was made; the bulk-upload API suite remained the authoritative end-to-end verification for this session.

### Long-term Fix
Debug `AddStudentDialog.test.tsx` timeouts, remove unwrapped asynchronous updates, and add focused tests for the institution bulk-upload dialogs.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- None.

## References
- `inst/src/components/AddStudentDialog.test.tsx`
- `inst/src/components/AddStudentDialog.tsx`

---

**Resolved By:** Pending
**Time to Resolution:** Investigation recorded
