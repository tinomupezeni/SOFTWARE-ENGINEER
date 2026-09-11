# Institution Account Able to Login to TESC Main System

**Date:** 2026-07-01
**Project:** TESC
**Environment:** Development/Production
**Severity:** High
**Status:** Resolved

## Summary
Institutional admin accounts created by TESC administrators were able to log in to the TESC main dashboard. Although a frontend block was in place, the backend API was issuing valid tokens to these accounts indiscriminately.

## Symptoms
- Institution users (created when an institution is added) could bypass intended restrictions and access the TESC main system instead of being confined to the Institution Portal.
- The frontend logic intended to block them (`fetchedUser?.institution`) did not prevent the backend from generating tokens, meaning direct API access or bypassed frontend logic permitted unauthorized access.

## Environment Details
- **Server/Host:** Local/Backend
- **Services Affected:** Authentication API (`/users/token/`, `/users/verify-otp/`)
- **Related Components:** `CustomTokenObtainPairSerializer`, `VerifyOTPSerializer`, `AuthContext.tsx`
- **Time First Observed:** 2026-07-01

## Investigation Steps

### 1. Initial Diagnosis
- Checked the `AuthContext.tsx` in the frontend and found an existing block (`if (fetchedUser?.institution) throw new Error(...)`).
- Investigated the backend authentication flow in `users/serializers/auth_serializers.py`.

### 2. Root Cause Analysis
- Examined `CustomTokenObtainPairSerializer.validate` and `VerifyOTPSerializer.validate`.
- Discovered that the backend API (`/users/token/` and `/users/verify-otp/`) was successfully issuing access and refresh tokens to institution accounts without checking if they were authorized to access the main TESC system.

### 3. Key Findings
- The frontend was solely responsible for enforcing the boundary between TESC Main and the Institution Portal, which is insecure.
- Institution admins are given `is_staff=True` and `level='1'` when created, making them indistinguishable from regular super admins if the `institution` field is not strictly validated during token issuance.

## Root Cause
The backend serializers for TESC Main (`CustomTokenObtainPairSerializer` and `VerifyOTPSerializer`) did not check whether a user was associated with an `institution` or had an `inst_admin` role before issuing JWT tokens. This allowed institution users to authenticate successfully against the main API.

## Solution

### Immediate Fix
Added explicit validation blocks in `backend/users/serializers/auth_serializers.py` to prevent token issuance for institution accounts on the main TESC login endpoint.

```python
# Added to CustomTokenObtainPairSerializer.validate and VerifyOTPSerializer.validate
if getattr(user, 'institution', None) or hasattr(user, 'inst_admin'):
    raise serializers.ValidationError({"detail": "Institution accounts are not authorized to access the main dashboard. Please use the Institution Portal."})
```

### Long-term Fix
Ensure all future authentication endpoints strictly validate user roles and institution associations at the API level rather than relying solely on frontend enforcement.

## Prevention
- [x] Code changes required (Added API-level validation)
- [ ] Documentation to update

## Related Issues
- N/A

## References
- `backend/users/serializers/auth_serializers.py`

---

**Resolved By:** Antigravity AI
**Time to Resolution:** ~10 minutes
