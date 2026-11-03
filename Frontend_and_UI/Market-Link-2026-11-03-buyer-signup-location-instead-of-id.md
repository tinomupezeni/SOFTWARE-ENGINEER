# Buyer Signup Asked for ID Instead of Location

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local checkout and read-only production inspection
**Severity:** Medium
**Status:** Resolved in deployed release 34274f0

## Summary
The deployed buyer form required an ID Photo URL. The requested buyer contract is a business name and location, with the location prompt `Enter Location` and placeholder `Harare, Zimbabwe`.

## Symptoms
- Buyers saw an ID Photo URL field instead of a location field.
- The local work in this session had briefly changed the ID link to an image upload; that change was superseded before deployment.

## Environment Details
- **Server/Host:** `agromarket-vm` (`/home/user/Documents/agromarket`); local checkout
- **Services Affected:** Buyer registration UI and API
- **Related Components:** `frontend/src/pages/auth/Register.tsx`, `backend/controllers/authController.js`, `backend/models/User.js`
- **Time First Observed:** 2026-11-03 user clarification

## Investigation Steps

### 1. Initial Diagnosis
Read the local form, controller, schema, and deployed form over SSH.

### 2. Root Cause Analysis
The old buyer contract required `idPhotoUrl` in the form and User schema. Buyer location was not validated or copied by the registration controller.

```bash
ssh -F /home/shadowe/.ssh/config agromarket-vm "grep -nE 'ID Photo URL|Enter Location|idPhotoUrl' /home/user/Documents/agromarket/frontend/src/pages/auth/Register.tsx"
```

### 3. Key Findings
- The deployed form still has `ID Photo URL`.
- Existing `farmLocation` can store buyer location without changing persisted document shape for older buyers.
- Adding a schema-level buyer required constraint would reject validation of old buyer records, so registration enforces it at the API boundary.

## Root Cause
The registration contract modeled buyer identity evidence as a URL and omitted buyer location.

## Prevention / Rule
**Guardrail:** Keep a buyer signup test that checks the visible location field and verifies that the submitted API payload includes `farmLocation` and no ID field.

This checks both the form and the registration contract used by the backend.

## Solution

### Immediate Fix
Removed the ID input and upload path, added the requested location prompt, validated it for buyers, and stored it in `farmLocation`. The admin buyer table now shows location.

### Long-term Fix
Deploy the reviewed changes and run a real buyer signup journey against the live API.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `Integrations_and_Auth/Market-Link-2026-11-03-buyer-id-link-replaced-with-private-image.md` (superseded before deployment)

## References
- `frontend/src/pages/auth/Register.tsx`
- `backend/controllers/authController.js`
- `backend/tests/auth-regressions.test.js`
- `frontend/src/pages/auth/Register.test.tsx`

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Same work session; deployment pending

## Verification

- `npm run test:flows` passed the buyer registration contract check.
- `CI=true npm test -- --watch=false --runInBand` passed the visible field and payload check.
- The frontend production build succeeded. The live checkout was not changed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
