# TESC production SMTP alignment

**Date:** 2026-10-17
**Project:** TESC
**Type:** Configuration Remediation / Production Verification
**Status:** Completed

## Summary
Aligned production email delivery with the verified staging configuration so
OTP messages are sent through `mails.hpc.ac.zw` from `noreply@hpc.ac.zw`
instead of the personal Gmail sender. The backend and Celery worker were
recreated and the complete OTP dispatch path was verified.

## Context / Trigger
After production account provisioning, production was found to still use
`mupezeni2001@gmail.com` for SMTP authentication and outbound mail. The user
requested that production use the institutional `noreply@hpc.ac.zw` settings
already working in staging.

## Scope
Included staging/production configuration comparison, production environment
backup, secure transfer of the matching mail settings without exposing the
SMTP password, container recreation, SMTP authentication, real message
submission, OTP login triggering, and service stability checks.

## Method
Compared resolved Docker Compose environment values while redacting secret
values. Used staging as the source of truth for the seven email settings,
updated only corresponding production `.env` keys, recreated services so
environment injection took effect, then tested SMTP directly and through the
production OTP login flow.

## Decisions & Findings
- Staging configuration was the correct source:
  `mails.hpc.ac.zw:587`, TLS enabled, SSL disabled, and
  `noreply@hpc.ac.zw` as both SMTP user and default sender.
- Production `.env` was backed up before modification.
- Both backend and Celery worker needed recreation; a restart alone would not
  reliably replace container environment variables.
- Direct SMTP authentication and message submission succeeded.
- A production login returned `requires_otp: true`, and the Celery OTP task
  completed successfully in approximately 0.54 seconds.
- Backend and worker remained running with restart count zero.

## Changes Made
- Updated the seven production mail settings from staging.
- Recreated `tesc-main-backend-1` and `tesc-main-celery-worker-1`.
- Preserved the pre-change production environment backup.
- Logged the configuration-drift issue in
  `Integrations_and_Auth/TESC-2026-10-17-production-smtp-sender-drift.md`.

## Verification
- Production containers reported:
  `EMAIL_HOST=mails.hpc.ac.zw`,
  `EMAIL_HOST_USER=noreply@hpc.ac.zw`, and
  `DEFAULT_FROM_EMAIL=noreply@hpc.ac.zw`.
- SMTP TLS authentication succeeded from the worker container.
- A real SMTP message submission returned an empty refusal map, indicating
  acceptance by the relay.
- Main-app login returned HTTP 200 with `requires_otp: true`.
- Celery reported the OTP task succeeded.
- Backend and worker restart counts remained zero.

## Follow-ups / Deferred
- Rotate the previously exposed SMTP credential.
- Add an automated staging/production mail-configuration parity check.
- Resolve the existing Celery root-user hardening warning.
- Move secrets to a managed configuration source rather than host `.env`
  files.

## References
- TESC production SMTP drift issue log
- `backend/users/tasks.py`
- Staging `/home/user/TESC/.env`
- Production `/home/user/Documents/TESC-main/.env`

---

**Completed By:** Copilot
**Duration:** Same session
