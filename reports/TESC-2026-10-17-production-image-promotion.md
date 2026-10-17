# TESC production image promotion and verification

**Date:** 2026-10-17
**Project:** TESC
**Type:** Release / Deployment Verification
**Status:** Completed

## Summary
Promoted the verified staging backend and institution frontend images to
production, applied and checked database migrations, fixed a production
startup crash loop caused by non-idempotent superuser bootstrap logic, and
completed container, proxy, frontend, API, and invalid-input verification.
Production is stable with the promoted services running without restart
loops.

## Context / Trigger
The user requested promotion of the updated staging images to the production
VM with a fresh backup, migration safety checks, rollback readiness, and a
final health check confirming that no service was crash-looping.

## Scope
Included production database backup, image transfer and rollback tagging,
migration application, backend and worker recreation, nginx routing refresh,
public frontend/API checks, and deployed bulk-commit validation checks.
Credential rotation, production `DEBUG` hardening, and reconciliation of
pre-existing dirty files on the production VM were explicitly deferred.

## Method
Followed the deployment runbook: inspect the live compose topology, create and
verify a custom-format database backup, preserve current images with
timestamped rollback tags, transfer images built in staging without rebuilding
on production, run migrations and drift checks, recreate dependent services,
then verify public routing and service stability. When the backend entered a
restart loop, logs were inspected before applying a surgical startup guard
fix and repeating the rollout checks.

## Decisions & Findings
- The production database was behind on nine migrations; all applied
  successfully.
- `migrate --check` and `makemigrations --check --dry-run` passed afterward.
- The backend initially crash-looped because bootstrap checked the seed
  superuser email but not the already-existing `admin` username.
- Nginx retained the old backend container IP after recreation; an explicit
  nginx restart restored API proxying.
- Bare `/api/` returns the expected Django HTTP 404; it no longer returns
  HTTP 502.
- Invalid scholarship and malformed student commit payloads are rejected by
  the deployed validation code rather than being accepted or causing a
  missing-field crash.

## Changes Made
- Promoted the staging backend image and institution frontend image to the
  live production compose tags.
- Created `/home/user/backups/tesc_predeploy_20261017T064513Z.dump` and
  verified it with `pg_restore --list`.
- Created timestamped rollback tags for the previous backend and institution
  images.
- Applied the production migrations.
- Fixed `backend/startup.sh` in TESC commit `13b5ebc` so seed-user creation
  checks both username and email.
- Rebuilt and transferred the corrected backend image, then recreated the
  backend and Celery worker.
- Restarted dependent frontends and nginx to refresh service routing.

## Verification
- Public main and institution frontends: HTTP 200.
- Public `/api/` and institution `/api/`: HTTP 404, confirming Django routing
  instead of proxy failure.
- Invalid public token request: HTTP 401 from Django.
- Backend, Celery, PostgreSQL, Redis, both frontends, and nginx: running with
  restart count zero.
- Celery connected to Redis and reported ready.
- Migration and model-drift checks passed.
- Direct invalid production commit checks raised validation errors for
  negative scholarship amounts and malformed student records.
- No new backend, worker, or nginx fatal errors were observed after the
  final restart; earlier 502 entries were from the pre-refresh check.

## Follow-ups / Deferred
- Rotate the SMTP credential previously exposed during the earlier email
  setup.
- Set production `DEBUG=False` after confirming any required operational
  diagnostics.
- Run Celery as a non-root user.
- Deploy the same commit to remote staging and rerun its two historical
  direct-commit edge cases.
- Replace reused commit-like image tags with immutable release tags and
  reconcile pre-existing dirty production files.

## References
- TESC commit `13b5ebc`
- `backend/startup.sh`
- `backend/academic/services/ingestion_service.py`
- `project_docs/09-deployment-and-operations.md`
- `SOFTWARE-ENGINEER/Integrations_and_Auth/TESC-2026-10-17-production-startup-superuser-crash-loop.md`

---

**Completed By:** Copilot
**Duration:** Same deployment session
