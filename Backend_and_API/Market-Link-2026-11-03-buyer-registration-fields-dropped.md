# Buyer Registration Fields Are Dropped Before Schema Validation

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Development code review (deployment state not verified)
**Severity:** High
**Status:** Resolved in deployed release 34274f0

## Summary
The buyer registration form collects `businessName` and `idPhotoUrl`, and the User schema requires both for buyers. The registration controller omits both when constructing `userData`, so `User.create` fails validation for every buyer registration.

## Symptoms
- A buyer submitting the complete form receives a registration failure.
- No runtime request was tested in this read-only review.

## Environment Details
- **Server/Host:** Repository checkout; production not inspected
- **Services Affected:** Buyer registration API
- **Related Components:** `frontend/src/pages/auth/Register.tsx`, `backend/controllers/authController.js`, `backend/models/User.js`
- **Time First Observed:** 2026-11-03

## Investigation Steps

### 1. Initial Diagnosis
Compared form payload fields, controller destructuring, and schema requirements.

### 2. Root Cause Analysis
The form sends the buyer fields. The controller extracts only common and farmer fields and builds `userData` without buyer fields. Mongoose requires those fields when `role === 'buyer'`.

```bash
rg -n 'businessName|idPhotoUrl|userData' frontend/src/pages/auth/Register.tsx backend/controllers/authController.js backend/models/User.js
```

### 3. Key Findings
- Frontend validates and submits both buyer fields.
- Controller does not copy either field into `User.create`.
- Schema rejects buyer records without them.

## Root Cause
Registration payload handling drifted from the buyer schema.

## Prevention / Rule
**Guardrail:** Add a registration contract test that submits each supported role's real form payload and asserts the resulting persisted fields.

This catches dropped role-specific fields before release.

## Solution

### Immediate Fix
The local registration controller now validates and copies `businessName` and `idPhotoUrl` to the User model. Production deployment remains pending.

### Long-term Fix
Keep role-specific registration fields in a shared schema or contract test across form, controller, and model.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `Backend_and_API/Market-Link-2026-09-18-farmsize-registration-validation.md`

## References
- `frontend/src/pages/auth/Register.tsx:117-118`
- `frontend/src/pages/auth/Register.tsx:140-149`
- `backend/controllers/authController.js:30-39`
- `backend/controllers/authController.js:112-125`
- `backend/models/User.js:62-72`

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Same work session; deployment pending

## Verification

- `npm run test:auth` confirms a complete buyer payload returns 201, validates both persisted fields against the User schema, and rejects a missing business name with 400.
- Production deployment and smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
