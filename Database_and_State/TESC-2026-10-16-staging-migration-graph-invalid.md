# [TESC] Staging Database Migration Graph Referenced a Missing Parent

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** High
**Status:** Resolved in code; migration rerun pending

## Summary
The staging backend could not run Django migrations because `academic.0020_merge_staging_student_migrations` declared a dependency on `academic.0019_student_academic_st_status_f931b2_idx_and_more`, but that migration file was absent from the deployed branch.

## Symptoms
- Password-reset API returned HTTP 500.
- Backend logs reported `users_customuser` did not exist.
- `python manage.py migrate --noinput` failed before applying migrations with `NodeNotFoundError`.

## Environment Details
- **Server/Host:** TESC staging Docker Compose runtime
- **Services Affected:** Django backend and staging database initialization
- **Related Components:** `backend/academic/migrations/0020_merge_staging_student_migrations.py`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
The deployed backend and Celery worker started successfully, and a directly queued OTP task completed. The real password-reset endpoint still returned HTTP 500, so backend logs and migration status were inspected.

### 2. Root Cause Analysis
The database was empty because migrations had not run. Running `manage.py migrate --noinput` failed while loading the migration graph: migration `0020` referenced a nonexistent `0019_student_academic_st_status_f931b2_idx_and_more` parent. The repository contains only `0019_student_gender_unspecified.py`.

### 3. Key Findings
- `users_customuser` was absent because initialization stopped before any migrations applied.
- The invalid dependency was introduced by commit `5787aa1` (`Merge staging academic migrations`).
- The existing `0019_student_gender_unspecified` migration is the only present `0019` parent.

## Root Cause
A merge migration retained a dependency from another migration branch without including that parent migration file, leaving Django's migration graph inconsistent.

## Prevention / Rule
**Guardrail:** Run `python manage.py makemigrations --check` and `python manage.py migrate --plan` in the deployment gate before starting a fresh environment.

These checks load and validate the complete migration graph before deployment, catching missing parent nodes before the runtime receives traffic.

## Solution

### Immediate Fix
Removed the dependency on the absent migration from `0020_merge_staging_student_migrations.py`.

### Long-term Fix
Add migration graph validation to CI and require a fresh-database migration smoke test for staging Compose deployments.

## Prevention
- [x] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `TESC-2026-10-16-staging-celery-worker-missing.md`
- `TESC-2026-10-16-staging-otp-email-bypassed.md`

## References
- `backend/academic/migrations/0019_student_gender_unspecified.py`
- `backend/academic/migrations/0020_merge_staging_student_migrations.py`
- Commit `5787aa1`

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
