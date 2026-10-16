# [TESC] Staging OTP Email Was Bypassed by DEBUG Mode

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** High
**Status:** Resolved in code; staging deployment pending

## Summary
Staging login appeared not to send OTP email even though direct SMTP tests succeeded. The staging Compose configuration set `DEBUG=True`, and the authentication serializers treated Django debug mode as an OTP bypass. Normal staging login therefore returned tokens without queueing the email task.

## Symptoms
- Direct SMTP delivery from `noreply@hpc.ac.zw` succeeded.
- System-triggered OTP email was not received.
- Staging authentication did not create an OTP email task.

## Environment Details
- **Server/Host:** TESC staging environment
- **Services Affected:** Django authentication API and Celery email worker
- **Related Components:** `docker-compose.staging.yml`, JWT login serializers, institution authentication service
- **Time First Observed:** 2026-10-14

## Investigation Steps

### 1. Initial Diagnosis
The SMTP host, credentials, TLS connection, sender address, and Gmail recipient were tested directly. SMTP authentication succeeded and the relay accepted messages, proving the mail server was not the initial failure point.

### 2. Root Cause Analysis
The login path was traced from the token serializer and institution authentication service to `send_otp_task.delay(...)`. Both paths used `settings.DEBUG` as an OTP bypass condition. Staging explicitly sets `DEBUG=True`, so the email task was skipped.

### 3. Key Findings
- `docker-compose.staging.yml` sets `DEBUG=True`.
- `CustomTokenObtainPairSerializer` bypassed OTP whenever `settings.DEBUG` was true.
- `authenticate_institution_user` used the same implicit debug bypass.
- Email task exceptions were captured by Sentry but swallowed, making worker delivery failures invisible to callers and normal logs.
- A synchronous in-memory execution of `send_otp_task` produced the expected message from `noreply@hpc.ac.zw` to the target recipient.

## Root Cause
Authentication behavior was coupled to the global Django debug flag. Because staging ran in debug mode, the application intentionally skipped OTP generation and email dispatch. The task-level broad exception handling also reduced observability for any subsequent worker or SMTP failure.

## Prevention / Rule
**Guardrail:** OTP bypass must be controlled only by an explicit `OTP_BYPASS` environment setting or an authenticated smoke-test header, never by `DEBUG`.

An explicit feature flag separates developer diagnostics from authentication behavior and prevents staging from silently disabling security-critical email flows.

## Solution

### Immediate Fix
- Added explicit `OTP_BYPASS`, defaulting to `False`.
- Replaced `settings.DEBUG` OTP bypass checks in both authentication paths with `settings.OTP_BYPASS`.
- Added error logging and re-raised exceptions in both email tasks so Celery failures are visible and actionable.
- Added `OTP_BYPASS=False` to the environment template.

### Long-term Fix
Deploy the updated backend and Celery worker to staging, verify the effective runtime value of `OTP_BYPASS`, and perform a real login/OTP flow while monitoring worker logs.

## Prevention
- [x] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `backend/users/serializers/auth_serializers.py`
- `backend/instauth/services/auth_service.py`
- `backend/users/tasks.py`
- `docker-compose.staging.yml`

---

**Resolved By:** Copilot
**Time to Resolution:** Same investigation session
