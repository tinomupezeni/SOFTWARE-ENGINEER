# Staging User Management Shows No Last-Login Activity

**Date:** 2026-09-01 (root-caused and resolved 2026-09-09)
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The staging Admin User Management screen showed all users as `Never` logged in, including accounts that had been used for a long time. This indicates that authentication may be succeeding while the login-audit field is not being updated, or that the screen is reading a different user record/database than the authentication path.

## Symptoms
- User Management displayed active accounts with `Last Login: Never`.
- The report came from staging only; production was not included in the request.
- The issue was observed after the team had been actively logging into the system.

## Environment Details
- **Server/Host:** HBEC staging environment
- **Services Affected:** Admin User Management and login audit display
- **Related Components:** Admin frontend, authentication endpoint, user `last_login` persistence/query
- **Time First Observed:** 2026-09-01

## Investigation Steps

### 1. Initial Diagnosis
Compare the user record shown in staging with the record updated by a real staging login. Trace the login request through authentication, user persistence, and the User Management query.

### 2. Root Cause Analysis
The available CLI history confirms the discrepancy but does not establish whether the cause is missing persistence, a serializer/query field mismatch, stale frontend data, or different database connections.

### 3. Key Findings
- Authentication success and audit-record success are separate behaviors.
- A user-management page can look healthy while silently losing security-relevant login history.
- Staging must verify audit side effects, not only login response status.
- (2026-09-09) `apps/accounts/views.py::LoginView.post()` issues JWTs directly
  through `LoginSerializer.validate()` — it never calls Django's own
  `django.contrib.auth.login()`. Django's automatic `last_login` update is a
  receiver on the `user_logged_in` signal, which only fires from `login()`.
  A custom JWT view that authenticates and mints tokens by hand bypasses that
  entire chain, silently, with no error — `authenticate()` itself does not
  touch `last_login` either. Nothing else in the login path wrote to the
  field, so it stayed `NULL` forever regardless of how often anyone logged in.

## Root Cause
`LoginView`/`LoginSerializer` (custom JWT login) never triggers Django's
`user_logged_in` signal or otherwise updates `last_login` — a known gap in
hand-rolled DRF+SimpleJWT login views that don't call `django.contrib.auth.login()`.

## Solution

### Immediate Fix
None needed in production data — no historical logins were ever recorded, so
there was nothing to backfill; the field is simply `NULL` until each user's
next real login.

### Long-term Fix
`LoginSerializer.validate()` now calls `django.contrib.auth.models.update_last_login(None, user)` —
the exact function Django's own signal receiver calls — right after
authentication succeeds, before issuing tokens. Not called on a failed
login, and not called on token refresh (which extends a session rather than
starting one). 3 new tests added: successful login sets `last_login`, a
second login advances it, a failed login leaves it untouched.

## Prevention
- [x] Trace and fix the missing `last_login` persistence or read path
- [x] Add login-audit integration coverage (`apps/accounts/tests/test_login.py`)
- [ ] Add staging smoke coverage for User Management audit fields
- [x] Verify authentication and admin screens use the same staging database (confirmed — same DB, the field was just never written)

## Related Issues
- Guide 19: Issue-to-Verified-Production Engineering Workflow

## References
- Antigravity CLI history, HBEC workspace, 2026-09-01
- `ADMIN/adminBackend/apps/accounts/serializers.py` (fix)
- `ADMIN/adminBackend/apps/accounts/tests/test_login.py` (regression tests)
- Commit `27fcf885`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** ~8 days from first report to root cause + fix (2026-09-01 → 2026-09-09)
