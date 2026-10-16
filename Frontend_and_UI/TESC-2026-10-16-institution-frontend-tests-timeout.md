# [TESC] Institution Frontend Student Dialog Tests Time Out

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Development validation
**Severity:** Medium
**Status:** Resolved

## Summary
The institution frontend production build passed, but the Vitest suite had 7 failures, all timeouts in `src/components/AddStudentDialog.test.tsx`. The failures were caused by stale test fixtures that omitted fields now required by the dialog.

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
The failing tests stopped at the dialog's required-field guard, while API, auth, hook, and other component tests passed. The tests omitted required National ID and/or Date of Birth values, so they never reached the success, API-error, loading, or reset assertions.

### 3. Key Findings
- 7 of 39 tests initially failed.
- 32 tests initially passed.
- Failures are isolated to AddStudentDialog tests.
- The production bundle builds successfully.
- After valid required fields were supplied, all eight dialog tests passed.

## Root Cause
The test fixtures were stale after Date of Birth became a required field, and several submission-path fixtures also omitted National ID.

## Prevention / Rule
**Guardrail:** Require the institution frontend Vitest suite to pass in CI, with submission-path fixtures satisfying the component's required-field contract.

This prevents UI data-entry regressions from being hidden by a green production build alone and catches stale fixtures when required fields change.

## Solution

### Immediate Fix
Updated `inst/src/components/AddStudentDialog.test.tsx` so every submission-path test supplies valid National ID and Date of Birth values.

### Long-term Fix
Added institution frontend test and build steps to `.github/workflows/ci.yml`.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `inst/src/components/AddStudentDialog.test.tsx`
- `inst/src/components/AddStudentDialog.tsx`

---

**Resolved By:** Copilot
**Time to Resolution:** Same validation session

## Verification

```bash
cd inst
npm test -- --run src/components/AddStudentDialog.test.tsx --reporter=dot
```

Result: **1 test file passed, 8 tests passed**.
