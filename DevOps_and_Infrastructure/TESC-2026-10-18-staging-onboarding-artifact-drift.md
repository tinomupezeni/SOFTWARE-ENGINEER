# Staging Onboarding Artifact Drift

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Environment:** Staging
**Severity:** High
**Status:** Investigating

## Summary

The staging main user-creation journey is serving older frontend and backend
artifacts than the local onboarding fix. The live frontend still displays the
static-password dialog and generates a `first.last` username, while the live
backend serializer still contains the `tesc@123` fallback and does not send
the new invitation task. This caused the current 400 to be diagnosed through
staging logs as a username-only uniqueness conflict rather than the email
conflict that was removed.

## Symptoms

- `POST /api/users/users/` returns HTTP 400 during the staging test.
- Recent nginx responses are 58 bytes, matching the DRF body:
  `{"username":["A user with that username already exists."]}`.
- The deleted email has no remaining case-insensitive email or username match.
- The live UI bundle still contains `Default Password` and the `tesc@123`
  fallback.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** `tesc-backend-1`, live main frontend bundle
- **Related Components:** main user onboarding, staging artifact promotion
- **Time First Observed:** 2026-10-18 09:05 CAT

## Investigation Steps

### 1. Initial Diagnosis

Checked recent backend and nginx logs, verified the deleted identifier was
absent, and inspected the public staging JavaScript bundle.

### 2. Root Cause Analysis

The public bundle contains the older create flow:

```text
username: `${firstName.toLowerCase()}.${lastName.toLowerCase()}`
password: response.password || "tesc@123"
```

The live backend source still contains:

```python
user.set_password("tesc@123")
```

The source changes that generate random credentials and queue invitations
exist only in the local worktree and have not been deployed to staging.

### 3. Key Findings

- Email `massala.care@gmail.com` is currently free on staging.
- The 400 response size is consistent with a username uniqueness error only.
- The exact generated username depends on the first and last names entered in
  the form; deleting the email account does not release a different colliding
  username.
- Staging is not yet exercising the new invitation implementation.

## Root Cause

Staging artifact/source drift left the old onboarding implementation deployed.
The old client derives a separate username from the entered name, and the
backend enforces username uniqueness globally. The browser console reports only
the HTTP status, hiding the validation body that identifies the actual field.

## Prevention / Rule

**Guardrail:** Every staging deployment must verify frontend bundle identity and
backend source/commit identity, then run a user-creation smoke test that
asserts the response body and invitation-task handoff.

This prevents a successful-looking deployment from leaving the tested staging
journey on an older onboarding contract.

## Solution

### Immediate Fix

No application or staging data was changed during this diagnosis. The
conflicting account was already removed, and the remaining failure is the
generated username collision plus stale staging artifacts.

### Long-term Fix

Deploy the committed main invitation changes to staging, then verify the exact
frontend bundle, backend task registration, and controlled user-creation
journey.

## Prevention

- [ ] Promote the exact onboarding backend artifact
- [ ] Promote the matching main frontend artifact
- [ ] Add response-body assertion to staging smoke checks
- [ ] Replace generic frontend 400 toast with field-level validation details

## References

- `backend/users/serializers/settings_serializers.py`
- `frontend/src/pages/Settings.tsx`
- `reports/TESC-2026-10-18-massala-staging-user-removal.md`

---

**Resolved By:** Pending staging deployment
**Time to Resolution:** Investigation completed
