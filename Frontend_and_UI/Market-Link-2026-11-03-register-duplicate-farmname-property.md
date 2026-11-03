# Duplicate Farm Name Declarations in Registration Form

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Development code review (deployment state not verified)
**Severity:** Medium
**Status:** Resolved in deployed release 34274f0

## Summary
`Register.tsx` declares `farmName` twice in both form interfaces and twice in the initial object literal. TypeScript rejects duplicate declarations and object properties, which prevents a clean frontend build.

## Symptoms
- Duplicate `farmName` entries are present at lines 31-32, 47-48, and 69-70.
- Build could not be run because local frontend dependencies are not installed.

## Environment Details
- **Server/Host:** Repository checkout
- **Services Affected:** React frontend build
- **Related Components:** `frontend/src/pages/auth/Register.tsx`
- **Time First Observed:** 2026-11-03

## Investigation Steps

### 1. Initial Diagnosis
Read the registration component while tracing the account flow.

### 2. Root Cause Analysis
The same property was duplicated in declarations and initialization, likely during a form edit.

```bash
rg -n 'farmName' frontend/src/pages/auth/Register.tsx
```

### 3. Key Findings
- The interface and object literal contain repeated property names.
- Local `frontend/node_modules/.bin/tsc` is absent, so compilation was not verified here.

## Root Cause
Repeated form field edits left duplicate TypeScript members and initializer keys.

## Prevention / Rule
**Guardrail:** Require `npm run build` for the frontend in CI on every pull request.

TypeScript compilation catches duplicate declarations and object keys before deployment.

## Solution

### Immediate Fix
Removed duplicate `farmName` interface members and initializer property from the local checkout. Production deployment remains pending.

### Long-term Fix
Make frontend build a required merge check.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- None identified.

## References
- `frontend/src/pages/auth/Register.tsx:31-32`
- `frontend/src/pages/auth/Register.tsx:47-48`
- `frontend/src/pages/auth/Register.tsx:69-70`

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Same work session; deployment pending

## Verification

- The duplicate entries are gone; frontend production build result is recorded in the work-session summary.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
