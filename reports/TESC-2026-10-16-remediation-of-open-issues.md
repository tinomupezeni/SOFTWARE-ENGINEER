# TESC Open-Issue Remediation

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Type:** Bug remediation / Deployment hardening / Testing
**Status:** Completed with operational follow-ups deferred

## Summary
Resolved the active institution frontend test and validation defects, hardened
staging and production-side repository deployment checks, and corrected the
stale status of the migration, Celery, and OTP issue records. VM-dependent
HTTPS certificate provisioning, credential rotation/history scrubbing, and
off-host backup scheduling remain explicitly deferred because they require
infrastructure access and operational approvals.

## Context / Trigger
The TESC engineering-log scan identified four active records and three stale
records. The user requested that the open items be worked through and fixed.

## Scope
Included:
- Institution frontend dialog tests and validation behavior.
- Deployment migration verification and startup failure handling.
- Staging Celery/OTP/migration issue status accuracy.
- Repository-side secret-file and database-backup controls.

Excluded:
- Force-pushing rewritten Git history.
- Production certificate installation or backup scheduling without VM access,
  certificate ownership, and an approved off-host destination.

## Method
Reproduced the frontend failures, traced the submit and validation state
transitions, implemented focused fixes, ran targeted and full frontend tests,
validated shell and Compose configuration, and compared each engineering log
against verified staging evidence.

## Decisions & Findings
- Dialog submission tests were stale because required National ID and Date of
  Birth values were omitted.
- National ID validation state was not cleared when the user corrected the
  field; this was a separate component defect.
- Staging Celery worker, migration graph, and OTP bypass fixes were already
  deployed and verified, so their records were stale rather than unresolved.
- Deployment now uses Compose service names and an explicit migration check.
- Repository-side controls can prevent new tracked environment/SQL files, but
  historical secrets still require coordinated rotation and history cleanup.
- Production Compose already includes nginx and Redis; certificate-backed HTTPS
  and off-host backup retention remain VM operations.

## Changes Made

### TESC
- Updated `inst/src/components/AddStudentDialog.test.tsx` with complete,
  stable required-field fixtures and a file-local 15-second UI test timeout.
- Updated `inst/src/components/AddStudentDialog.tsx` to clear stale National ID
  errors on input change.
- Added institution frontend tests and build to `.github/workflows/ci.yml`.
- Added migration graph checks to CI.
- Hardened `scripts/deploy.sh` with Compose service execution and
  `manage.py migrate --check`.
- Removed startup error suppression from `backend/startup.sh`.
- Added `scripts/backup_database.sh` with archive validation.
- Removed `.env` and `backend/.env` from the Git index while preserving local
  runtime files.
- Updated deployment and testing documentation.

### SOFTWARE-ENGINEER
- Resolved the frontend timeout, National ID validation, staging Celery,
  migration graph, OTP bypass, and silent migration deployment records.
- Updated infrastructure and technical-debt audits to distinguish applied
  repository controls from deferred VM operations.

## Verification
- Institution frontend: **8 test files passed, 39 tests passed**.
- Institution frontend production build passed.
- `bash -n scripts/deploy.sh backend/startup.sh scripts/backup_database.sh`
  passed.
- `docker compose -f docker-compose.prod.yml config --quiet` passed.
- `git ls-files` no longer includes `.env`, `backend/.env`, or SQL dumps.
- Staging evidence confirms real OTP task consumption by Celery and successful
  migration application.

## Follow-ups / Deferred
- Rotate the SMTP and any other credentials exposed in historical repository
  objects.
- Coordinate a `git filter-repo` history rewrite only with all clone/branch
  owners.
- Configure certificate-backed HTTPS and HTTP-to-HTTPS redirect on the VM.
- Schedule the validated backup helper to an off-host destination and perform
  a restore drill.
- Evaluate a rolling deployment strategy for the single-VM topology.

## References
- `SOFTWARE-ENGINEER/DevOps_and_Infrastructure/TESC-2026-06-30-principal-engineer-audit.md`
- `SOFTWARE-ENGINEER/DevOps_and_Infrastructure/TESC-2026-06-30-technical-debt-audit.md`
- `TESC` commits `1f0748a`, `00829c0`

---

**Completed By:** Copilot
**Duration:** Same remediation session
