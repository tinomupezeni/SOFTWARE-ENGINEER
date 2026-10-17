# TESC institution user invitation flow audit

**Date:** 2026-10-17
**Project:** TESC
**Type:** Audit / Release Readiness
**Status:** Completed

## Summary
Tested and completed the staging institution user-provisioning flow from
administrator creation through invitation-task execution and cleanup. The
flow now generates a random temporary password, persists only its hash,
queues an invitation after commit, and preserves the required first-login
password change.

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
- **User creation:** PASS — authenticated ZCHPC administrator received HTTP
  201 from `POST /api/instauth/users/`.
- **Account persistence:** PASS — the user was linked to ZCHPC with the
  selected role and `must_change_password=True`.
- **Random password generation:** PASS — the persisted account did not accept
  the former static password `scalareye@123`; the generated plaintext was not
  logged or returned by the API.
- **Invitation email:** PASS at service level — Celery received and completed
  `send_institution_user_invitation_task`, and staging SMTP authentication
  succeeded using the configured institutional relay.
- **Institution first login and password change:** PASS in the focused
  regression tests and prior staging flow; the login contract returns
  `must_change_password=True` and the profile update clears it after a
  successful password change.
- **Tenant isolation:** PASS — role validation prevents assigning a role from
  another institution.
- **Cleanup:** PASS — the temporary staging user was deleted and the backend
  and worker remained healthy with no restart loop.

## Changes Made
- Implemented and deployed the invitation flow in TESC commit `c87a555`.
- Rebuilt and recreated the staging backend and Celery worker.
- Configured the staging institution portal URL as
  `https://tesc-inst-staging.zchpc.ac.zw`.
- Removed the temporary staging account and its test data.

## Verification
- Focused staging regression tests: **2 passed**.
- Staging user creation: **HTTP 201**.
- Celery invitation task: **received and succeeded**.
- SMTP relay authentication: **passed**.
- Persisted test account: random-password behavior and forced-change flag
  verified.
- Backend and Celery worker: running without a restart loop after cleanup.

## Follow-ups / Deferred
- Promote the verified implementation to production only after an explicit
  production deployment decision.
- Confirm rendered invitation content and receipt in an approved real mailbox;
  this staging check verified task execution and SMTP authentication but did
  not inspect mailbox contents.
- Consider returning an explicit invitation-queued status or delivery status
  to API callers.

## References
- Institution invitation email issue log
- `backend/instauth/serializers/user_management_serializers.py`
- `backend/instauth/views/user_management_views.py`
- `backend/users/tasks.py`

---

**Completed By:** Copilot
**Duration:** Same session
