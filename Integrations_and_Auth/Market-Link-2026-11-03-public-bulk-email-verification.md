# Public Route Can Verify Every Unverified Account

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Development code review (deployment state not verified)
**Severity:** Critical
**Status:** Resolved — confirmed by `npm run test:auth` (404 on both bulk-verify routes); deployed in release 34274f0

## Summary
The public `GET /api/auth/verify-all-old-users` route sets `isVerified: true` on every currently unverified user. Any caller can bypass email verification for all accounts.

## Symptoms
- An unauthenticated request to the route can bulk-verify accounts.
- No runtime request or production impact was tested in this read-only review.

## Environment Details
- **Server/Host:** Repository checkout; production not inspected
- **Services Affected:** Express authentication API, MongoDB users
- **Related Components:** `backend/routes/authRoutes.js`, `backend/controllers/authController.js`
- **Time First Observed:** 2026-11-03

## Investigation Steps

### 1. Initial Diagnosis
Traced the authentication route table while mapping the codebase.

### 2. Root Cause Analysis
`authRoutes.js` mounts the migration route among public routes with no `protect` middleware. `verifyAllOldUsers` runs `User.updateMany({ isVerified: { $ne: true } }, { $set: { isVerified: true } })`.

```bash
rg -n 'verify-all-old-users|verifyAllOldUsers' backend/routes/authRoutes.js backend/controllers/authController.js
```

### 3. Key Findings
- Route is public and uses GET for a state-changing operation.
- Update criteria include newly registered unverified accounts, not only legacy users.
- The server mounts the router under both `/auth` and `/api/auth`.

## Root Cause
A one-time migration action was exposed as an unrestricted application endpoint and was never scoped to legacy accounts.

## Prevention / Rule
**Guardrail:** Keep bulk account migrations in offline scripts; reject public routes that call `User.updateMany` on verification state in a route-level security check.

This removes the external trigger for a global verification bypass.

## Solution

### Immediate Fix
Removed the bulk verification route and controller action from the local checkout. Production deployment and an audit of prior verification changes remain pending.

### Long-term Fix
Run any required legacy verification migration as an explicitly reviewed, scoped, one-time database operation.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- None identified.

## References
- `backend/routes/authRoutes.js:14`
- `backend/controllers/authController.js:452-466`

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Same work session; deployment pending

## Verification

- `npm run test:auth` confirms both `/auth/verify-all-old-users` and `/api/auth/verify-all-old-users` return 404 and no bulk update runs.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
