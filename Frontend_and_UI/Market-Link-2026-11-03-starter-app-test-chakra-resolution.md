# Starter App Test Cannot Resolve Chakra Module

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** Low
**Status:** Resolved in deployed release 34274f0

## Summary
The full frontend Jest run fails before the starter App test executes because Jest cannot resolve @chakra-ui/utils/context from the installed Chakra package.

## Symptoms
- The focused image URL test passes, but CI=true npm test fails in App.test.tsx.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** frontend/src/App.test.tsx; frontend/package.json; frontend/package-lock.json
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
The starter App test imports the whole app and hits a Chakra package/Jest resolver mismatch; the test itself still asserts obsolete create-react-app text.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- The starter App test imports the whole app and hits a Chakra package/Jest resolver mismatch; the test itself still asserts obsolete create-react-app text.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
The starter App test imports the whole app and hits a Chakra package/Jest resolver mismatch; the test itself still asserts obsolete create-react-app text.

## Prevention / Rule
**Guardrail:** Replace the stale starter test with a meaningful app smoke test after resolving the Chakra Jest module mapping or dependency mismatch.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
Added Jest module mappings for Chakra and React Router subpaths, supplied browser APIs missing from jsdom, and replaced the obsolete starter assertion with a MarketLink home page smoke assertion.

### Long-term Fix
Deploy the reviewed code and configuration, run the affected user journey on the target environment, and make the focused regression command a release gate.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- See other Market-Link entries dated 2026-11-03 for the connected registration, upload, and email flows.

## References
- frontend/src/App.test.tsx; frontend/package.json; frontend/package-lock.json

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Same work session; deployment pending

## Verification

- `CI=true npm test -- --watch=false --runInBand` now passes both the App smoke test and image URL test. The original failure was reproduced before the fix.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
