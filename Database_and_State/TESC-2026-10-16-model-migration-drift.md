# [TESC] Staging Model State Drifted From Tracked Migrations

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging / CI
**Severity:** Medium
**Status:** Resolved

## Summary
The deployed staging database had no pending migrations, but Django detected
model changes that were not represented by tracked migration files. This would
cause the newly added migration CI gate to fail and would leave new indexes and
an ISEOP gender-field contract change unmanaged.

## Symptoms
- `manage.py migrate` reported no migrations to apply while warning that
  `academic` and `iseop` models had unapplied changes.
- `manage.py makemigrations --check` proposed `academic.0021` and
  `iseop.0004`.

## Root Cause
Model changes were committed without the corresponding generated migration
files.

## Prevention / Rule
**Guardrail:** CI runs `manage.py makemigrations --check` before deployment and
fails when model state differs from tracked migrations.

## Solution
Generated and committed:
- `backend/academic/migrations/0021_student_academic_st_status_f931b2_idx_and_more.py`
- `backend/iseop/migrations/0004_alter_iseopstudent_gender.py`

## Verification
The migrations were applied to staging after deployment, followed by
`manage.py migrate --check`. The migration check then reported no pending
migrations.

---

**Resolved By:** Copilot
**Time to Resolution:** Same staging deployment session
