# Staging Invitation Worker Rejected Main User Task

**Date:** 2026-10-18
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Workaround Applied

## Summary
Main-user creation successfully queued
`users.tasks.send_user_invitation_task`, but staging email delivery did not
occur because an old orphan Celery worker consumed the message without that
task registered. The worker rejected the message as an unregistered task and
discarded it.

## Symptoms
- A newly created main user was not sent login details.
- Staging worker logs reported:
  `Received unregistered task of type 'users.tasks.send_user_invitation_task'`.
- The task payload contained the correct staging portal URL, proving dispatch
  occurred before worker rejection.

## Environment Details
- **Server/Host:** `10.50.1.37`
- **Services Affected:** `tesc-celery-worker-1`, `tesc-celery_worker-1`
- **Related Components:** Celery, Docker Compose, backend image/source parity
- **Time First Observed:** 2026-10-18

## Investigation Steps

### 1. Initial Diagnosis
Compared backend logs, worker logs, task registration, running images, and
container mounts on staging. The backend created the account and published the
invitation task.

### 2. Root Cause Analysis
Staging had two workers:

- `tesc-celery-worker-1`: an old orphan worker with a bind-mounted source tree.
- `tesc-celery_worker-1`: the Compose-managed worker using an image-only
  deployment.

The image-only worker was still based on an artifact that did not contain the
new main invitation task. It consumed the message and raised a Celery
unregistered-task error.

### 3. Key Findings
- The backend runtime had `send_user_invitation_task`.
- The stale worker rejected the task at `07:51:04Z`.
- Production is still on the older onboarding flow: it registers only the
  institution invitation task and uses `noreply@hpc.ac.zw`.
- Staging runtime sender is `noreply@zchpc.ac.zw`.

## Root Cause
Worker artifact parity was not enforced. Backend source was updated through a
bind mount, but the image-only worker was not rebuilt from the same source, and
an orphan worker remained attached to the shared queue.

## Prevention / Rule
**Guardrail:** A deployment gate must inspect every active Celery worker and
fail unless each worker registers the required invitation task from the same
artifact identity as the backend.

This prevents queue consumers with incompatible task registries from silently
discarding newly published onboarding messages.

## Solution

### Immediate Fix
- Stopped and removed only the obsolete `tesc-celery-worker-1` container.
- Rebuilt the Compose-managed `celery_worker` image from current staging source.
- Recreated `tesc-celery_worker-1`.
- Verified `users.tasks.send_user_invitation_task` is registered and the worker
  reaches ready state.

### Long-term Fix
Add worker registration and artifact-identity checks to the staging and
production deployment verification script. Remove ambiguous duplicate service
names and prevent orphan workers from sharing the production queue.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- Staging onboarding artifact drift.
- Main invitation sender/template issue.
- Staging invitation localhost URL issue.

## References
- `backend/users/tasks.py`
- `backend/users/serializers/settings_serializers.py`
- `/home/user/TESC/docker-compose.prod.yml`
- Staging worker log at `2026-10-18T07:51:04Z`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
