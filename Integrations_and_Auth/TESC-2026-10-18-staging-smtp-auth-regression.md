# Staging SMTP Authentication Failed for Main Invitations

**Date:** 2026-10-18
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Workaround Applied

## Summary
Staging main-user invitation tasks reached the correct Celery worker but did
not deliver because SMTP authentication for `noreply@zchpc.ac.zw` failed with
SMTP 535. The SMTP socket also had no timeout, causing the Celery task to
remain active instead of reporting a bounded failure.

## Symptoms
- The invitation task was received by Celery but no email arrived.
- Staging SMTP authentication returned `535 authentication failed` for the
  configured `noreply@zchpc.ac.zw` identity.
- A later authentication attempt timed out while waiting for the relay.
- The task had no configured `EMAIL_TIMEOUT`.

## Environment Details
- **Server/Host:** `10.50.1.37`
- **Services Affected:** `tesc-backend-1`, `tesc-celery_worker-1`
- **Related Components:** Django SMTP backend, Celery invitation task, staging `.env`
- **Time First Observed:** 2026-10-18

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the task was registered, received, and active in the current worker.
The relay accepted TCP connections and returned an SMTP greeting.

### 2. Root Cause Analysis
TLS negotiation succeeded, but authentication using the staging
`noreply@zchpc.ac.zw` configuration failed. Production authentication using
its existing `noreply@hpc.ac.zw` configuration succeeded. Secret digests were
compared without exposing the secret and matched, indicating the failure was
specific to relay/account handling rather than a missing environment value.

### 3. Key Findings
- Production uses `noreply@hpc.ac.zw` and authenticates successfully.
- Staging was configured for `noreply@zchpc.ac.zw` and failed authentication.
- After staging was aligned to the production sender identity,
  authentication succeeded.
- `EMAIL_TIMEOUT=30` now bounds SMTP operations.

## Root Cause
Staging used a sender identity that the SMTP relay did not consistently
authenticate, and the SMTP backend had no timeout, masking the provider
failure as a missing email.

## Prevention / Rule
**Guardrail:** Deployment validation must perform bounded SMTP TLS and
authentication checks using the exact runtime sender identity before enabling
user onboarding.

This catches sender/account authorization drift and prevents indefinite Celery
tasks when the relay does not complete authentication.

## Solution

### Immediate Fix
- Set staging `EMAIL_HOST_USER` and `DEFAULT_FROM_EMAIL` to the
  production-proven `noreply@hpc.ac.zw`.
- Added `EMAIL_TIMEOUT=30`.
- Recreated backend and worker containers.
- Verified staging SMTP authentication succeeds without exposing credentials.

### Long-term Fix
Confirm with the mail administrator whether `noreply@zchpc.ac.zw` should be
provisioned and authorized, or standardize the deployment on the working
`noreply@hpc.ac.zw` identity.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Main invitation worker artifact-parity regression.
- Main invitation sender/template configuration issue.

## References
- `backend/core/settings.py`
- `backend/users/tasks.py`
- Staging and production runtime SMTP probes

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
