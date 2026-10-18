# Institution User Hidden From Main User List

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Environment:** Staging
**Severity:** Medium
**Status:** Investigating

## Summary

The staging account `massala.care@gmail.com` exists, but it is institution
scoped rather than a main/global account. The main user-management view hides
institution-scoped accounts while the database-wide username and email
constraints still reject creating another account with the same identifiers.
This makes the account appear absent while producing a duplicate-username
error.

## Symptoms

- Adding `massala.care@gmail.com` through the main TESC user-management flow
  reports that the username is already taken.
- The account is not visible in the main/global user list.
- The same email and username are already present on staging.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** Main user management and institution user management
- **Related Components:** `CustomUser`, `UserSerializer`, `UserViewSet`
- **Time First Observed:** 2026-10-18 09:02 CAT

## Investigation Steps

### 1. Initial Diagnosis

Queried staging directly from the backend container for case-insensitive email
and username matches, then inspected institution, role, department, and
account-state fields.

### 2. Root Cause Analysis

The account exists as user ID `224` with both email and username set to
`massala.care@gmail.com`. It belongs to institution ID `21` (`ZCHPC`), has role
`Migrated Role: Applications (Tinotenda)`, and department `Applications`.

The main user queryset intentionally filters global users with
`institution__isnull=True` for a system administrator. The model's unique
username and email constraints remain global, so a hidden institution user
still blocks a new main account.

### 3. Key Findings

- No separate global/main account exists for this email.
- The existing account is active, non-staff, non-superuser, and has not logged
  in (`last_login` is null).
- `must_change_password` is currently false.
- Direct serializer validation reproduces both duplicate errors:
  `A user with that username already exists.` and
  `user with this email already exists.`

## Root Cause

Visibility is tenant-scoped but identifier uniqueness is database-wide. The UI
does not explain that a matching institution account exists outside the main
scope, so the user sees a misleading duplicate error instead of an actionable
scope conflict.

## Prevention / Rule

**Guardrail:** When main user creation is rejected by a globally unique email
or username, return an explicit scope-conflict error for an existing
institution-scoped account and include the owning institution name only for an
authorized system administrator.

This preserves global uniqueness while explaining why the account is not
visible in the current list.

## Solution

### Immediate Fix

No data was changed and no account was deleted or reassigned. The existing
staging account was confirmed as institution-scoped.

### Long-term Fix

Add an authorized scope-conflict response and corresponding frontend message,
then add a regression test proving that an institution user hidden from the
main list produces an actionable error.

## Prevention

- [ ] Add scope-aware duplicate error handling
- [ ] Add backend regression test
- [ ] Add frontend error-message coverage
- [ ] Document whether institution accounts may be promoted to global accounts

## References

- `backend/users/models.py`
- `backend/users/views/settings_views.py`
- `backend/users/serializers/settings_serializers.py`

---

**Resolved By:** Pending product decision and implementation
**Time to Resolution:** Investigation completed
