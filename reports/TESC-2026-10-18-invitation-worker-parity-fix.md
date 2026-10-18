# TESC Invitation Worker Parity Fix

**Date:** 2026-10-18
**Project:** TESC
**Type:** Deployment Fix / Configuration Parity
**Status:** Completed

## Summary
Investigated why staging stopped sending main-user invitation emails, compared
staging with production, and corrected the staging Celery worker artifact. The
failure was not SMTP configuration: the task was published with the correct
staging URL but rejected by an incompatible orphan worker.

## Context / Trigger
After deleting and recreating the staging test account, no invitation email
arrived. The request was to inspect logs and compare how production handles the
institutional no-reply sender.

## Scope
Included staging backend/worker logs, Celery task registration, container
images/mounts, runtime email configuration, and production task/sender
comparison. No production services or data were changed.

## Method
Read recent backend and worker logs, inspected active Compose services and
container artifacts, queried effective Django settings inside both environments,
and rebuilt only the incompatible staging worker from the current backend
source.

## Decisions & Findings
- Staging did publish `users.tasks.send_user_invitation_task`.
- The task was rejected by `tesc-celery_worker-1` as unregistered.
- An older orphan `tesc-celery-worker-1` also existed and shared the queue.
- Production currently uses the older institution-only invitation path and
  `noreply@hpc.ac.zw`; it is not a valid reference for the new main-user flow.
- Staging uses `noreply@zchpc.ac.zw` and the correct staging portal URL.

## Changes Made
- Removed the stale staging worker container `tesc-celery-worker-1`.
- Rebuilt and recreated the Compose-managed staging `celery_worker`.
- Verified the new worker contains `users.tasks.send_user_invitation_task`.

## Verification
- Worker registration includes `users.tasks.send_user_invitation_task`.
- Worker reached Celery ready state.
- Backend runtime continues to use `noreply@zchpc.ac.zw`.
- The failed task log shows dispatch reached the broker before rejection.

## Follow-ups / Deferred
- The account created during the failed attempt has no delivered credentials;
  it should be deleted and recreated for a clean test.
- Production main-user invitation onboarding and the sender migration remain
  separate deployment work and were intentionally not changed here.
- Add automated worker artifact/task-registry parity checks to deployment gates.

## References
- `DevOps_and_Infrastructure/TESC-2026-10-18-staging-invitation-worker-regression.md`
- `backend/users/tasks.py`
- `backend/users/serializers/settings_serializers.py`

---

**Completed By:** Copilot
**Duration:** Same session
