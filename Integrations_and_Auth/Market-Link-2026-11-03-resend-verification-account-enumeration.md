# Verification Resend Revealed Account State

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local code review; live deployment not inspected
**Severity:** Medium
**Status:** Resolved in deployed release 34274f0

## Summary
The public resend verification endpoint returned different responses for unknown, verified, and unverified email addresses, revealing account existence and status.

## Symptoms
- Unknown addresses received 404 and verified accounts received 400.
- Unverified accounts proceeded to email delivery.

## Environment Details
- **Server/Host:** Local checkout
- **Services Affected:** Authentication API
- **Related Components:** `backend/controllers/authController.js`, `backend/routes/authRoutes.js`
- **Time First Observed:** 2026-11-03

## Investigation Steps

### 1. Initial Diagnosis
Traced the resend flow while adding a retry path for missing verification email.

### 2. Root Cause Analysis
The endpoint exposed distinct status codes and messages from the user lookup and verification-state checks.

```bash
rg -n 'resendVerificationEmail|User not found|Email is already verified' backend/controllers/authController.js
```

### 3. Key Findings
- The route is public and accepts an email address.
- Differing responses allowed account-state probing.
- The forgot-password route already used a generic response for unknown accounts.

## Root Cause
Account lookup outcomes were returned directly from the public resend endpoint.

## Prevention / Rule
**Guardrail:** Public account recovery endpoints must return the same response for unknown and ineligible addresses; verify with a negative API test.

This prevents disclosure of user existence and verification state through status and message differences.

## Solution

### Immediate Fix
The local endpoint now returns the same generic success response for unknown and already verified addresses.

### Long-term Fix
Keep the negative response-equivalence test in the backend release suite and verify the deployed route.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `Integrations_and_Auth/Market-Link-2026-11-03-verification-email-failure-hidden.md`

## References
- `backend/controllers/authController.js`
- `backend/tests/auth-regressions.test.js`

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Same work session; deployment pending

## Verification

- `npm run test:flows` confirms unknown and verified addresses both receive the generic 200 response.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
