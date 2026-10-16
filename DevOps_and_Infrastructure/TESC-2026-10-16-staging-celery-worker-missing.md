# [TESC] Staging Compose Has No Celery Worker for Email Tasks

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The repository's staging Compose file defines Redis and a backend container but no Celery worker. The backend service command is also `tail -f /dev/null`, so any authentication or password-reset email task queued with `.delay(...)` can remain unconsumed if this Compose file is used as the staging runtime.

## Symptoms
- Direct SMTP sends succeed.
- Application-triggered email is not delivered.
- Authentication tasks publish asynchronously through Celery rather than sending in the request process.

## Environment Details
- **Server/Host:** TESC staging VM
- **Services Affected:** Celery email task execution
- **Related Components:** `docker-compose.staging.yml`, Redis, `users.tasks`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
The direct SMTP path was tested independently and successfully authenticated with `mails.hpc.ac.zw`, proving the mail server and app password work.

### 2. Root Cause Analysis
The application queues OTP and password-reset messages with `send_otp_task.delay(...)` and `send_password_reset_email_task.delay(...)`. The staging Compose file contains no `celery` service and configures `tesc-backend-staging-v2` with `tail -f /dev/null`, so it does not provide a worker process to consume Redis tasks.

### 3. Key Findings
- `docker-compose.staging.yml` now declares `redis`, `db`, `tesc-backend-staging-v2`, and `celery-worker-staging`.
- `celery-worker-staging` runs `celery -A core worker -l info`.
- The staging backend now runs Gunicorn instead of `tail -f /dev/null`.
- `docker-compose.prod.yml` does define a separate `celery_worker`, showing the required runtime pattern exists elsewhere in the repository.

## Root Cause
The staging runtime definition is incomplete for asynchronous email delivery: the producer and broker are present, but the consumer worker is absent.

## Prevention / Rule
**Guardrail:** Every Compose environment that enables Celery task production must declare and health-check a worker service in the same deployment manifest.

This prevents asynchronous tasks from being silently accepted into Redis without any process responsible for executing them.

## Solution

### Immediate Fix
Added the staging Celery worker service and replaced the idle backend command with Gunicorn in `docker-compose.staging.yml`.

### Long-term Fix
The staging verification now queues a real login OTP task and checks that the
Celery worker completes it before treating email delivery as healthy.

## Prevention
- [x] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `TESC-2026-10-16-staging-otp-email-bypassed.md`

## References
- `docker-compose.staging.yml`
- `docker-compose.prod.yml`
- `backend/users/tasks.py`
- `backend/users/serializers/auth_serializers.py`
- `backend/users/views/auth_views.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment remediation session

## Verification

- Staging backend, PostgreSQL, Redis, and Celery worker started successfully.
- A real login request returned `requires_otp: true`.
- The queued OTP task was consumed and completed by Celery in approximately
  2.5 seconds.
