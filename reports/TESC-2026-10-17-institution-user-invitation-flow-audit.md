# TESC institution user invitation flow audit

**Date:** 2026-10-17
**Project:** TESC
**Type:** Audit / Release Readiness
**Status:** Completed

## Summary
Tested the staging institution user-provisioning flow from administrator
creation through first login and password change. Account creation and
forced-password-change behavior work, but the requested random-password
invitation email workflow is missing.

## Context / Trigger
The user requested verification that an institution user can be created by
another institution user, receive random login credentials by email, log in
to the correct portal, and be forced to change the password on first login.

## Scope
Included authenticated ZCHPC institution-admin creation of a temporary user,
database persistence, password behavior, Celery/email activity, institution
login, first-login flag, password change, main-portal behavior, and cleanup.
No production account or code was changed.

## Method
Used the staging institution API with the existing ZCHPC administrator,
created a unique temporary account without supplying a password, inspected the
resulting database record and Celery logs, tested login and password change,
then deleted the temporary account.

## Decisions & Findings
- **User creation:** PASS — HTTP 201.
- **Account persistence:** PASS — user linked to ZCHPC with the selected role.
- **Random password generation:** FAIL — static fallback
  `scalareye@123` is used.
- **Invitation email:** FAIL — no invitation/password email task is queued.
- **Institution first login:** PASS — login succeeds and returns
  `must_change_password=True`.
- **Forced password change:** PASS — profile password update returns HTTP 200.
- **Main TESC portal:** PASS — institution account is rejected with HTTP 403,
  directing it to the Institution Portal.
- **Cleanup:** PASS — temporary user deleted with HTTP 204 and absent from DB.

## Changes Made
- No application code or production data changed.
- Reproduced and recorded the missing invitation-email defect.
- Removed the temporary staging account and its test data.

## Verification
- Staging institution API and database checks completed.
- Staging Celery logs showed no invitation/password email task for the newly
  created user.
- Static password login, first-login flag, password change, and main-portal
  rejection were directly tested.

## Follow-ups / Deferred
- Implement secure random credential or invitation-token generation.
- Add invitation email delivery through the institutional SMTP sender.
- Add an end-to-end regression test and release gate.
- Do not claim the institution user invitation workflow is complete until
  email receipt and first-login password change are tested with a real mailbox.

## References
- Institution invitation email issue log
- `backend/instauth/serializers/user_management_serializers.py`
- `backend/instauth/views/user_management_views.py`
- `backend/users/tasks.py`

---

**Completed By:** Copilot
**Duration:** Same session
