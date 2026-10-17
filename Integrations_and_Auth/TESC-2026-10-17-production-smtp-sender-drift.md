# Production SMTP sender configuration drift

**Date:** 2026-10-17
**Project:** TESC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Production was still configured to send OTP email through the personal Gmail
account `mupezeni2001@gmail.com`, while staging had already been migrated to
the institutional SMTP relay and sender `noreply@hpc.ac.zw`. Production was
updated to match the verified staging mail configuration.

## Symptoms
- OTP delivery configuration in production used the wrong sender identity.
- Production backend and Celery worker environment reported Gmail SMTP values.
- The intended institutional sender was not being used for authentication and
  default outbound mail.

## Environment Details
- **Server/Host:** Production VM `10.50.200.35`
- **Services Affected:** Django backend and Celery worker
- **Related Components:** Production `.env`, Django email settings, OTP task
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Compared the resolved Docker Compose environment on staging and production
without printing credential values.

### 2. Root Cause Analysis
Staging used the institutional relay `mails.hpc.ac.zw` with
`noreply@hpc.ac.zw` as both SMTP account and default sender. Production still
used `smtp.gmail.com`, `mupezeni2001@gmail.com`, and the Gmail sender.

### 3. Key Findings
- The staging `.env` was the verified source for the seven mail settings.
- Production `.env` had a pre-change backup before modification.
- Backend and worker both required recreation because environment variables
  are injected when containers are created.

## Root Cause
The production runtime had configuration drift from staging after the sender
migration. Image promotion did not update the separately managed production
`.env` file, so the application continued using the old Gmail transport.

## Prevention / Rule
**Guardrail:** Add a deployment smoke check that compares the resolved
production mail host and sender against the approved environment contract and
fails before release when production is configured with a personal sender.

This catches runtime configuration drift that image-only verification cannot
detect, while keeping the credential value itself out of logs and reports.

## Solution

### Immediate Fix
Copied only the seven approved mail settings from staging to production,
without displaying the SMTP password, and preserved a timestamped production
`.env` backup. Recreated the backend and Celery worker containers.

### Long-term Fix
Move environment secrets and approved non-secret mail configuration to a
managed deployment configuration source, and add automated parity validation
for staging-to-production mail settings.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- TESC email/OTP delivery records from the earlier staging migration
- Production credential rotation remains a separate security follow-up

## References
- Staging `/home/user/TESC/.env`
- Production `/home/user/Documents/TESC-main/.env`
- `backend/users/tasks.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
