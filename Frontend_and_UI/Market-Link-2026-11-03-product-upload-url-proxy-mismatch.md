# Product Upload URLs Did Not Follow API Proxy

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** High
**Status:** Resolved in deployed release 34274f0

## Summary
Uploaded product images were stored at /uploads paths while the documented public reverse proxy routes /api/ traffic to the backend.

## Symptoms
- Product images could fail to load even when the listing itself was visible.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** backend/server.js; backend/controllers/productController.js; frontend/src/services/api.ts
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
The frontend constructed image URLs from SERVER_URL and the backend exposed uploads outside the proxied /api/ path.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- The frontend constructed image URLs from SERVER_URL and the backend exposed uploads outside the proxied /api/ path.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
The frontend constructed image URLs from SERVER_URL and the backend exposed uploads outside the proxied /api/ path.

## Prevention / Rule
**Guardrail:** Serve uploads under /api/uploads and resolve both new and legacy upload paths through the API base URL.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
Added the API uploads route, stored new URLs under it, and centralized frontend resolution for existing and new records.

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
- backend/server.js; backend/controllers/productController.js; frontend/src/services/api.ts

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Local fix in this work session; deployment pending

## Verification

- `npm run test:flows` checks /api/uploads serves a file; the focused frontend API test covers legacy and new image paths.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
