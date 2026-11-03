# Password Reset Link Could Be Invalid or Undelivered

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** High
**Status:** Resolved — inbox receipt confirmed 2026-11-03 in post-release QA (`reports/Market-Link-2026-11-03-post-release-qa-verification.md`)

## Summary
Forgot password used an unqualified domain as its fallback frontend URL and depended on mail credentials that were not explicitly loaded into Compose.

## Symptoms
- Users reported no reset email; a sent link could lack an http(s) scheme.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** backend/controllers/authController.js; backend/.env.example; docker-compose.yml
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
The reset URL fallback was `agromarketing.co.zw`, the local frontend examples used port 3000 while the app runs on 3001, and mail configuration could be missing from the backend container.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- The reset URL fallback was `agromarketing.co.zw`, the local frontend examples used port 3000 while the app runs on 3001, and mail configuration could be missing from the backend container.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
The reset URL fallback was `agromarketing.co.zw`, the local frontend examples used port 3000 while the app runs on 3001, and mail configuration could be missing from the backend container.

## Prevention / Rule
**Guardrail:** Require a complete public frontend URL and working mail configuration before generating a reset token.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
Added full URL validation, corrected the local frontend fallback to port 3001, explicit mail configuration, and delivery failure logging while preserving non-enumerating responses for unknown addresses.

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
- backend/controllers/authController.js; backend/.env.example; docker-compose.yml

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Local fix in this work session; deployment pending

## Verification

- `npm run test:flows` checks an HTTPS reset URL and 503 for missing mail configuration. Live SMTP delivery remains unverified.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
