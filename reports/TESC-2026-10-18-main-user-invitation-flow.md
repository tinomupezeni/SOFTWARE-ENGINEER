# Main User Invitation Flow

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Type:** Bug Fix / Contract Integrity / Security Hardening
**Status:** Completed in source; staging deployment pending

## Summary

The main TESC user-creation flow was brought into parity with the institution
onboarding flow. New main-portal users now receive random temporary
credentials by email after commit, are forced to change the password at first
login, and cannot be assigned foreign institution roles or departments.

## Context / Trigger

Investigation showed that the main `/api/users/users/` path silently assigned
the known fallback password `tesc@123` and never queued an invitation email,
while institution onboarding already used random credentials and post-commit
delivery.

## Scope

Included the main user serializer, invitation task, frontend success dialog,
and focused backend regression tests. Staging deployment, controlled SMTP
delivery, and production promotion were intentionally deferred until the user
approves the deployment step.

## Method

Traced the frontend payload and backend serializer contract, compared it with
the working institution invitation implementation, added post-commit task
dispatch, and tested password hashing, forced-change state, rollback behavior,
and credential non-disclosure.

## Decisions & Findings

- Main invitations use a dedicated task and `settings.FRONTEND_URL`.
- Temporary passwords are generated with `secrets.token_urlsafe`.
- Passwords are never returned in the serializer response or shown in the
  frontend after creation.
- Institution/global role and department boundaries are enforced during
  serializer validation.
- Existing institution invitation behavior was left unchanged.

## Changes Made

- `backend/users/serializers/settings_serializers.py`
  - Removed the static fallback password.
  - Added random password generation, hashing, forced-change state, commit-hook
    dispatch, and tenant-scope validation.
- `backend/users/tasks.py`
  - Added `send_user_invitation_task`.
- `backend/users/tests.py`
  - Added main invitation and rollback regression tests.
- `frontend/src/pages/Settings.tsx`
  - Replaced credential display with an email-delivery confirmation.

## Verification

- `USE_SQLITE=True .venv/bin/python manage.py check`
- Main invitation suite: 3 tests passed; institution invitation suite: 2 tests
  passed.
- `git diff --check` passed.
- Local PostgreSQL-backed verification remains unavailable because no local
  PostgreSQL listener is running.

## Follow-ups / Deferred

- Deploy the scoped change to staging.
- Verify Celery registration and controlled SMTP handoff without exposing the
  temporary password.
- Verify first-login password change and cleanup the controlled test account.
- Consider extracting a shared onboarding service after staging validation.

## References

- `Integrations_and_Auth/TESC-2026-10-18-main-user-invitation-email-missing.md`
- `backend/instauth/serializers/user_management_serializers.py`
- `backend/users/serializers/settings_serializers.py`

---

**Completed By:** Copilot
**Duration:** One implementation session
