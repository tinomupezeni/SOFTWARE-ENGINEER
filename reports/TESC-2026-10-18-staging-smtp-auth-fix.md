# TESC Staging SMTP Authentication Fix

**Date:** 2026-10-18
**Project:** TESC
**Type:** Integration Fix / Configuration Parity
**Status:** Completed

## Summary
Diagnosed the second staging invitation failure as SMTP sender authentication
drift rather than a task-dispatch problem. Staging was aligned with the
production-proven sender, SMTP operations were bounded with a 30-second
timeout, and authentication was reverified.

## Context / Trigger
After the Celery worker artifact was repaired, the invitation task was received
but remained active without producing an email.

## Scope
Included staging SMTP connectivity, TLS, authentication, Django settings,
Celery task behavior, and comparison with production's working sender path.
No production configuration or data was changed.

## Method
Collected correlated worker state and logs, checked effective runtime settings,
probed TCP/SMTP/TLS/authentication with bounded timeouts, and compared only
non-secret configuration and secret digests between staging and production.

## Decisions & Findings
- The relay was reachable and TLS negotiation worked.
- Staging authentication for `noreply@zchpc.ac.zw` failed.
- Production authentication for `noreply@hpc.ac.zw` succeeded.
- Staging authentication succeeded after switching to `noreply@hpc.ac.zw`.
- The prior task was lost when the worker was recreated; the existing account
  must be recreated for a clean end-to-end test.

## Changes Made
- Added environment-configurable `EMAIL_TIMEOUT`, defaulting to 30 seconds.
- Set staging sender and SMTP user to `noreply@hpc.ac.zw`.
- Recreated staging backend and Celery worker.

## Verification
- Django checks passed.
- Current worker registers `users.tasks.send_user_invitation_task`.
- Staging runtime reports `EMAIL_TIMEOUT=30`.
- Staging bounded SMTP authentication: passed.
- Production bounded SMTP authentication: passed before comparison.

## Follow-ups / Deferred
- Delete and recreate the current staging test account because its previous
  invitation task was lost during worker recreation.
- Confirm whether the desired institutional sender should ultimately be
  `noreply@hpc.ac.zw` or provision a separately authorized
  `noreply@zchpc.ac.zw`.
- Perform a real controlled recipient delivery before marking the integration
  fully verified.

## References
- `Integrations_and_Auth/TESC-2026-10-18-staging-smtp-auth-regression.md`
- `backend/core/settings.py`
- `backend/users/tasks.py`

---

**Completed By:** Copilot
**Duration:** Same session
