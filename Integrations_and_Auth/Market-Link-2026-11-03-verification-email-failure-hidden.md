# Registration Hid Verification Email Delivery Failure

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** High
**Status:** Deployed in release 34274f0; SMTP acceptance verified, inbox receipt pending

## Summary
Registration returned success even when verification email delivery failed, and backend mail settings were absent from the active environment template and Compose configuration.

## Symptoms
- New users were told to check mail but received no verification link and could not log in.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** backend/controllers/authController.js; backend/.env.example; docker-compose.yml; frontend/src/pages/auth/VerifyEmailPrompt.tsx
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
The controller swallowed sendMail errors; the container did not explicitly load backend/.env, and the verification URL depended on request host.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- The controller swallowed sendMail errors; the container did not explicitly load backend/.env, and the verification URL depended on request host.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
The controller swallowed sendMail errors; the container did not explicitly load backend/.env, and the verification URL depended on request host.

## Prevention / Rule
**Guardrail:** Require mail credentials and a public API URL before creating an account, report transport failure, and provide a resend path.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
Added configuration checks, explicit Compose env loading, public URL construction, delivery status in the response, and a resend button.

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
- backend/controllers/authController.js; backend/.env.example; docker-compose.yml; frontend/src/pages/auth/VerifyEmailPrompt.tsx

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Local fix in this work session; deployment pending

## Verification

- `npm run test:flows` checks the generated HTTPS verification link, multipart registration, and the 202 response on a simulated delivery failure. Live SMTP delivery remains unverified.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
