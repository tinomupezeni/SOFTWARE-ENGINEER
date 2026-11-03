# Free Text Product Location Rejected as City

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout; reported by users, production state not independently verified
**Severity:** High
**Status:** Resolved in deployed release 34274f0

## Summary
Product creation copied the free text location into the enum constrained `city` field, causing Mongoose validation errors for ordinary addresses.

## Symptoms
- Farmers could submit a complete product form and receive a generic add product failure.

## Environment Details
- **Server/Host:** Local checkout; live host not inspected
- **Services Affected:** Market-Link application
- **Related Components:** backend/controllers/productController.js; backend/models/Product.js; frontend/src/pages/marketplace/AddProduct.tsx
- **Time First Observed:** 2026-11-03 user report and code investigation

## Investigation Steps

### 1. Initial Diagnosis
Traced the reported user journey through frontend, API route, controller, schema, and deployment configuration as applicable.

### 2. Root Cause Analysis
The form allows arbitrary location text; the controller assigned it to Product.city even though the schema only permits a fixed city list.

```bash
rg -n 'createProduct|imageUrl|idPhotoUrl|verifyemail|forgotpassword|EMAIL_|FRONTEND_URL' backend frontend/src
```

### 3. Key Findings
- The form allows arbitrary location text; the controller assigned it to Product.city even though the schema only permits a fixed city list.
- Live environment and provider behavior were not verified in this local session.

## Root Cause
The form allows arbitrary location text; the controller assigned it to Product.city even though the schema only permits a fixed city list.

## Prevention / Rule
**Guardrail:** Map known city names case insensitively and leave optional city unset for other locations; preserve the full text in farmLocation.

This guardrail matches the failure path identified above and should be required in the relevant release check.

## Solution

### Immediate Fix
The controller now normalizes a known city and keeps free text in farmLocation.

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
- backend/controllers/productController.js; backend/models/Product.js; frontend/src/pages/marketplace/AddProduct.tsx

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Local fix in this work session; deployment pending

## Verification

- `npm run test:flows` validates a product with Harare, Zimbabwe and a free text farm location.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
