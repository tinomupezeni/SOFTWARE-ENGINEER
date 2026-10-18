# Main Portal User Invitation Email Missing

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Environment:** Staging and source
**Severity:** High
**Status:** Investigating

## Summary

Institution-user creation correctly generates a temporary password, marks the
account for a forced password change, and queues an invitation email. The
main TESC user-creation path does not perform the equivalent email dispatch
and falls back to the static password `tesc@123` when no password is supplied.
The institution frontend also displays an obsolete static-password message
instead of directing the new user to their email.

## Symptoms

- Main portal user creation calls `POST /api/users/users/` but no invitation
  task or email dispatch is present in the serializer.
- Main user creation defaults to a known password when the request omits one.
- The institution frontend success toast still says:
  `Default password is: scalareye@123`.
- The institution backend itself now uses a random temporary password and
  queues the invitation task, creating a frontend/backend contract mismatch.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** Main user onboarding, institution user onboarding UX
- **Related Components:** `users.serializers.settings_serializers.UserSerializer`,
  `users.tasks`, `instauth.serializers.user_management_serializers`,
  `inst/src/components/AddUserDialog.tsx`
- **Time First Observed:** 2026-10-18 08:47 CAT

## Investigation Steps

### 1. Initial Diagnosis

Traced the main frontend user-create call and institution frontend user-create
call through their API services, serializers, and worker task registration.

### 2. Root Cause Analysis

The institution serializer contains:

```python
temporary_password = supplied_password or secrets.token_urlsafe(12)
transaction.on_commit(
    lambda: send_institution_user_invitation_task.delay(...)
)
```

The main `UserSerializer.create()` instead contains:

```python
if password is not None:
    user.set_password(password)
else:
    user.set_password("tesc@123")
```

It does not set `must_change_password` or queue an email task. The institution
frontend still presents the historical static password in its success toast.

### 3. Key Findings

- Staging worker has `users.tasks.send_institution_user_invitation_task`
  registered.
- Staging uses `django.core.mail.backends.smtp.EmailBackend`.
- Staging email configuration reports:
  `DEFAULT_FROM_EMAIL=noreply@hpc.ac.zw` and
  `EMAIL_HOST=mails.hpc.ac.zw`.
- Institution invitation regression tests pass under SQLite: 2 tests passed.
- No real account was created during this verification.
- The local PostgreSQL-backed invitation test was blocked because no local
  PostgreSQL listener is available; SQLite-mode tests passed.

## Root Cause

User onboarding was implemented consistently for institution-scoped users but
the separate main-portal `UserSerializer` was left on an older password-only
creation path. The two portal contracts therefore diverged: one sends a
random temporary credential by email, while the other silently provisions a
known fallback credential and sends nothing.

## Prevention / Rule

**Guardrail:** Add one shared onboarding service used by both main and
institution user-creation endpoints, with a contract test requiring random
temporary-password hashing, `must_change_password=True`, post-commit
invitation dispatch, and portal-specific login URL.

This prevents the same security and delivery behavior from being implemented
independently in two serializers and drifting again.

## Solution

### Immediate Fix

No production code was changed during this verification. The defect is
confirmed and remains open for implementation.

### Long-term Fix

Implement the shared invitation flow for main users, remove static-password
fallbacks and frontend password disclosure, add main-portal invitation tests,
then verify a real staging SMTP handoff using a controlled test recipient.

## Prevention

- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## References

- `backend/users/serializers/settings_serializers.py`
- `backend/instauth/serializers/user_management_serializers.py`
- `backend/users/tasks.py`
- `backend/instauth/tests.py`
- `inst/src/components/AddUserDialog.tsx`
- `frontend/src/services/settings.services.ts`

---

**Resolved By:** Pending implementation
**Time to Resolution:** Investigation session
