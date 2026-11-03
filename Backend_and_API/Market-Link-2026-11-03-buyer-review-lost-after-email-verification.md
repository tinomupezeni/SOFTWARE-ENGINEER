# Buyer Review Disappeared After Email Verification

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** Medium
**Status:** Deployed in release 34274f0; SMTP acceptance verified, inbox receipt pending

## Summary
The admin list used the same isVerified flag as email verification, so a buyer disappeared from review as soon as they clicked their email link.

## Symptoms
- Admins could lose the chance to inspect a newly uploaded buyer ID image.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** backend/models/User.js; backend/controllers/adminController.js
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
Email possession and buyer approval were stored in one boolean.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- Email possession and buyer approval were stored in one boolean.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
Email possession and buyer approval were stored in one boolean.

## Prevention / Rule
**Guardrail:** Track buyer approval separately while keeping email verification as the login gate.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
Added buyerApproved and made the admin list include new buyers until approval; admin approval no longer bypasses email verification.

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
- backend/models/User.js; backend/controllers/adminController.js

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Local fix in this work session; deployment pending

## Verification

- `npm run test:flows` checks review visibility and approval state independently of isVerified.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
