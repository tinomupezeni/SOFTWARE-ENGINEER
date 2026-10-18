# Main Invitation Sender and Template

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Environment:** Staging
**Severity:** High
**Status:** Deployed; SMTP verification blocked

## Summary

The main-user invitation email was delivered through the wrong configured
sender identity and used a plain, unbranded presentation. The invitation
configuration and template were updated for `noreply@zchpc.ac.zw` with a TESC
branded HTML layout and matching plain-text fallback.

## Symptoms

- The received invitation identified the old sender account rather than the
  requested ZCHPC no-reply identity.
- The email body was a minimal text-like message with exposed credential lines
  and no branded structure.
- Staging runtime reported `DEFAULT_FROM_EMAIL=noreply@hpc.ac.zw` before the
  change.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** Backend invitation task and Celery worker
- **Related Components:** `backend/core/settings.py`, `backend/users/tasks.py`
- **Time First Observed:** 2026-10-18 09:40 CAT

## Investigation Steps

### 1. Initial Diagnosis

Inspected the invitation task and compared it with the OTP task. Both used
`settings.DEFAULT_FROM_EMAIL`, but staging was configured with the old
`noreply@hpc.ac.zw` identity.

### 2. Root Cause Analysis

The task had no sender override; it correctly followed Django configuration.
The staging `.env` therefore determined the wrong sender. The invitation HTML
was also substantially less developed than the OTP template.

### 3. Key Findings

- Before deployment, staging reported:
  `DEFAULT_FROM_EMAIL=noreply@hpc.ac.zw`.
- The invitation task was registered and running, but used that value.
- Staging was updated to `DEFAULT_FROM_EMAIL=noreply@zchpc.ac.zw` and
  `EMAIL_HOST_USER=noreply@zchpc.ac.zw`.
- The SMTP authentication probe did not return within the verification
  timeout, so relay acceptance for the new mailbox remains unverified.

## Root Cause

The sender identity was changed in application expectations but not kept
consistent with the staging SMTP runtime configuration. The mail task itself
did not contain a hard-coded sender defect.

## Prevention / Rule

**Guardrail:** Staging release validation must assert the effective
`DEFAULT_FROM_EMAIL`, `EMAIL_HOST_USER`, and a bounded SMTP authentication
probe before allowing invitation-flow verification.

This catches sender drift before a user receives an email from an unintended
identity.

## Solution

### Immediate Fix

- Changed the settings fallback to `noreply@zchpc.ac.zw`.
- Updated staging `DEFAULT_FROM_EMAIL` and `EMAIL_HOST_USER`.
- Recreated backend and Celery services so the new environment was loaded.
- Redesigned the invitation email with a branded TESC header, credential card,
  sign-in button, security callout, footer, and plain-text fallback.

### Long-term Fix

Confirm that the ZCHPC mailbox credentials are valid for `mails.hpc.ac.zw`
and that the relay accepts the new sender identity. Add a bounded automated
SMTP readiness check to staging deployment verification.

## Prevention

- [x] Align staging sender configuration
- [x] Improve invitation HTML and plain-text content
- [x] Recreate services after environment change
- [ ] Complete bounded SMTP authentication verification
- [ ] Verify a controlled invitation delivery

## References

- `backend/core/settings.py`
- `backend/users/tasks.py`
- `reports/TESC-2026-10-18-main-invitation-staging-deployment.md`

---

**Resolved By:** Copilot
**Time to Resolution:** Same-day implementation; external SMTP verification pending
