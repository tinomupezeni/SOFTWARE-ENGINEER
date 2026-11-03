# Admin Buyer Review Used Wrong URL and Missing Token

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** High
**Status:** Deployed in release 34274f0; automated checks passed, live admin path pending

## Summary
The admin dashboard built /api/admin requests by adding /api to an API base URL and read a token property that AuthContext did not provide.

## Symptoms
- Admin buyer review and ID image access could fail with wrong URLs or unauthorized responses.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** frontend/src/pages/dashboard/AdminDashboard.tsx; frontend/src/services/api.ts; frontend/src/contexts/AuthContext.tsx
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
AdminDashboard bypassed the shared API base and token storage contract.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- AdminDashboard bypassed the shared API base and token storage contract.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
AdminDashboard bypassed the shared API base and token storage contract.

## Prevention / Rule
**Guardrail:** Use the normalized API_BASE_URL and current stored token for every admin request; fetch private ID images with Authorization.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
Updated admin requests and private image preview to use the shared API base and Bearer token.

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
- frontend/src/pages/dashboard/AdminDashboard.tsx; frontend/src/services/api.ts; frontend/src/contexts/AuthContext.tsx

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Local fix in this work session; deployment pending

## Verification

- Frontend build succeeded; backend ID image route rejects anonymous and farmer requests and serves admin requests.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
