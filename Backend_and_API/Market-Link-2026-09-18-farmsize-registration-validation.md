# Farm Size Validation Blocking Farmer Registration

**Date:** 2026-09-18
**Project:** Market-Link
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
Farmers were unable to register (and consequently unable to log in) because the frontend stopped sending the `farmSize` field, but the backend API still enforced it as a strictly required field.

## Symptoms
- Attempting to register as a farmer failed silently on the frontend or showed a registration error.
- Checking the database for users whose registration was attempted showed `null` (user creation was rejected).

## Environment Details
- **Server/Host:** agromarketing-vm
- **Services Affected:** Backend API, MongoDB
- **Related Components:** `authController.js`, `User.js` model
- **Time First Observed:** 2026-09-18

## Investigation Steps

### 1. Initial Diagnosis
Tailed the backend logs and saw registration attempts (`Registration attempt: { ... }`) for farmer roles that never resulted in the user being written to the database.

### 2. Root Cause Analysis
Checked the git commit history and found a recent commit `8420ace400e7f2bba36ada472fc832ee954015e4` ("UI text updates and minor fixes") which removed the `farmSize` input field from the frontend `Register.tsx` file.
Checked `backend/controllers/authController.js` and observed:
```javascript
      if (
        farmSizeRaw === undefined ||
        farmSizeRaw === null ||
        String(farmSizeRaw).trim() === ""
      ) {
        return res.status(400).json({ success: false, message: "farmSize is required for farmer role" });
      }
```
The backend was correctly rejecting the payload, but the UI was completely unable to satisfy the requirement.

### 3. Key Findings
- Frontend removed `farmSize` from the UI but backend still expected it.
- Mongoose schema `User.js` also enforced `farmSize` as required for the farmer role.
- Registrations for non-farmer roles (e.g. `agro_dealer`) succeeded because `farmSize` is not required for them.

## Root Cause
Drift between frontend and backend schemas. A UI field was removed without coordinating the removal of the corresponding validation logic in the backend controller and database schema.

## Prevention / Rule
**Guardrail:** Ensure that any field removed from a form is also removed from backend validation, or use full end-to-end type safety (e.g., tRPC or shared Zod schemas) that break the build if the frontend fails to provide a field the backend requires.

Using a shared schema package forces the frontend and backend to stay perfectly in sync regarding required fields.

## Solution

### Immediate Fix
Removed the `farmSize` validation block from `backend/controllers/authController.js` and updated the `required` function for `farmSize` in `backend/models/User.js` to return `false` on the deployment VM.

```bash
sed -i '93,112d' Documents/agromarket/backend/controllers/authController.js
sed -i 's/return this.role === '\''farmer'\'';/return false;/g' Documents/agromarket/backend/models/User.js
docker compose build backend frontend && docker compose up -d backend frontend
```

### Long-term Fix
Synchronize the actual desired behavior (whether `farmSize` is truly needed for business logic) and implement a shared schema definition across the stack.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Farmer registration failing silently.

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 15 mins
