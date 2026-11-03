# Product Form Submitted Each Image Twice

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** High
**Status:** Resolved in deployed release 34274f0

## Summary
The product form constructed FormData from the file input and appended the same selected files again from React state.

## Symptoms
- Selecting three images could send six files and exceed the backend limit of five, preventing product creation.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** frontend/src/pages/marketplace/AddProduct.tsx; backend/routes/productRoutes.js
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
FormData(form) already includes the named file input; a second append duplicated every selected image.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- FormData(form) already includes the named file input; a second append duplicated every selected image.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
FormData(form) already includes the named file input; a second append duplicated every selected image.

## Prevention / Rule
**Guardrail:** Use the file input as the sole FormData source and reject selections above five before submission.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
Removed duplicate append logic and added a five image check with the actual API error shown to the user.

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
- frontend/src/pages/marketplace/AddProduct.tsx; backend/routes/productRoutes.js

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Local fix in this work session; deployment pending

## Verification

- Frontend build succeeded; backend product creation and image URL tests passed. Browser file-selection journey remains to be verified.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
