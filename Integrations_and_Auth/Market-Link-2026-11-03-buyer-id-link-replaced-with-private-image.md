# Buyer ID Required a Link Instead of an Upload

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** Medium
**Status:** Superseded by buyer location requirement on 2026-11-03

## Summary
Buyer registration required users to supply an external URL for their ID photo and the admin dashboard opened that link directly.

## Symptoms
- Buyers could not upload an ID image from their device.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** frontend/src/pages/auth/Register.tsx; backend/middleware/upload.js; backend/routes/adminRoutes.js; backend/controllers/adminController.js
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
The registration contract modeled ID evidence as a URL with no upload path or private retrieval route.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- The registration contract modeled ID evidence as a URL with no upload path or private retrieval route.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
The registration contract modeled ID evidence as a URL with no upload path or private retrieval route.

## Prevention / Rule
**Guardrail:** Accept an image file and store it outside the public uploads directory; allow only authenticated admins to retrieve it.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
Buyer registration now accepts JPEG, PNG, or WebP images up to 5 MB, stores them privately, and offers an authenticated admin preview.

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
- frontend/src/pages/auth/Register.tsx; backend/middleware/upload.js; backend/routes/adminRoutes.js; backend/controllers/adminController.js

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Local fix in this work session; deployment pending

## Verification

- `npm run test:flows` validates multipart buyer registration and negative authorization tests for the ID image route.
- Production deployment and smoke verification have not been performed.

## Superseded in the same work session

The product owner clarified that buyer signup should collect location instead of any ID photo or link. The private-image implementation described above was removed before deployment. The current local buyer flow requires a business name and location; see `Frontend_and_UI/Market-Link-2026-11-03-buyer-signup-location-instead-of-id.md`. No ID image endpoint remains in the local code.
