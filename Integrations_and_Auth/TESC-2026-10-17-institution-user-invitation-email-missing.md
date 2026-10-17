# Institution user invitation email missing

**Date:** 2026-10-17
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Investigating

## Summary
The institution user-creation endpoint creates a valid account and marks it
for a first-login password change, but it does not generate a random password
or email login details to the new user. When no password is supplied, the
serializer silently assigns the shared static password `scalareye@123`.

## Symptoms
- Institution administrator can create a user successfully with HTTP 201.
- New user has `must_change_password=True`.
- No password-invitation email task is queued or delivered.
- The created account can log in using the static fallback password.
- The account can change its password through the institution profile endpoint.

## Environment Details
- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** Institution user management, authentication, email
- **Related Components:** `InstitutionUserSerializer`, `InstitutionUserViewSet`,
  institution login, Celery email tasks
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Authenticated as the staging ZCHPC institution administrator and created a
temporary user through:
`POST /api/instauth/users/`.

### 2. Root Cause Analysis
`InstitutionUserSerializer.create()` removes an optional password from the
payload and uses `scalareye@123` when it is absent. It sets
`must_change_password=True`, but does not generate a random credential or
dispatch an email task.

### 3. Key Findings
- Temporary user creation returned HTTP 201.
- Database password verification succeeded for `scalareye@123`.
- No `send_password_reset_email_task` or invitation task appeared in recent
  staging Celery logs.
- Institution login with the static password returned HTTP 200 and
  `must_change_password=True`.
- `PATCH /api/instauth/profile/` changed the password successfully and
  returned HTTP 200.
- Attempting the main TESC portal correctly returned HTTP 403:
  institution accounts must use the Institution Portal.
- The temporary test account was deleted successfully with HTTP 204.

## Root Cause
The institution user serializer implements forced password change as a flag
only. It does not implement the corresponding invitation workflow, and its
static default password creates a shared-credential risk.

## Prevention / Rule
**Guardrail:** Institution user creation must reject absent passwords unless
the service generates a cryptographically random one, stores only its hash,
and dispatches a durable invitation task before returning success.

This prevents accounts from being created with an undocumented shared
credential and makes successful provisioning dependent on a usable invitation
path.

## Solution

### Immediate Fix
No production change was made. The staging defect was reproduced and the
temporary account was removed.

### Long-term Fix
- Generate a secure one-time random password or invitation token.
- Add a dedicated invitation email task using `noreply@hpc.ac.zw`.
- Include the institution portal URL and first-login password-change
  requirement.
- Fail visibly if invitation dispatch cannot be queued.
- Add an end-to-end test covering creation, email dispatch, first login, and
  password change.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Existing TESC email/OTP delivery records
- Production SMTP sender alignment

## References
- `backend/instauth/serializers/user_management_serializers.py`
- `backend/instauth/views/user_management_views.py`
- `backend/instauth/views/auth_views.py`
- `backend/users/tasks.py`

---

**Resolved By:** Not resolved; staging defect reproduced
**Time to Resolution:** Investigation only
