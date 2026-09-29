# Staging DB schema drift: migrations marked applied, DDL missing

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Environment:** Staging (erp-vm, `zchpc-erp-staging` stack)
**Severity:** Medium
**Status:** Resolved (staging DB rebuilt)

## Summary

While verifying an unrelated fix on staging, the service layer raised
`column hr_employees.department_id does not exist` — yet `showmigrations
hr` showed every migration `[X]` applied, including a `0016_merge`
from the DB's birth (2026-08-27). The staging `hr_employees` table had
14 columns vs 24 on a fresh migrate (prod: 32, a superset — safe).
Resolved by rebuilding the staging database from scratch; prod was
verified unaffected (column diff).

## Symptoms

- `DjangoEmployeeService.get_active_employees()` →
  `ProgrammingError: column hr_employees.department_id does not exist`
  on staging only.

## Environment Details

- **Server/Host:** erp-vm staging (`zchpc_staging_db`, volume
  `zchpc-erp-staging_postgres_data`, born 2026-08-27)
- **Services Affected:** staging API (any HR read touching post-0002 columns)
- **Time First Observed:** 2026-09-29 during PR #35 verification

## Investigation Steps

### 1. Initial Diagnosis

Compared `information_schema` for `hr_employees` across DBs and against
a fresh migrate; checked `django_migrations` timestamps and the `0012`
data migration content.

### 2. Root Cause Analysis

Staging's table predates columns its migration state claims to have
created — consistent with the DB being restored from an old dump *with*
a migrated `django_migrations` table, or migrations once `--fake`d.
Either way, migration state lied about schema. It went unnoticed because
nothing exercised those columns on staging (health checks don't touch
them — same blind spot as always).

### 3. Key Findings

- Prod is a superset (8 legacy leftover columns: `bio`, `photo`,
  `skills`, `tin`, …) with nothing missing → prod reads safe.
- Fresh staging migrate yields exactly the code-defined 24 columns.

## Root Cause

Staging database assembled out-of-band (dump restore / faked
migrations) so `django_migrations` and the real schema diverged; no
check ever compared them.

## Prevention / Rule

**Guardrail:** after any staging DB restore/seed, run `manage.py migrate`
plus a schema sanity query (or `makemigrations --check --dry-run` in CI
for model/state drift); treat staging data as disposable and rebuildable
from migrations + seeds rather than hand-maintained.

## Solution

### Immediate Fix

`docker compose down`, removed `zchpc-erp-staging_postgres_data`, `up`
fresh (migrations replayed for real). Re-seeded two verification rows
(`H059`, `EMP0001`) + temp superuser; full login→token→list proof passed.

### Long-term Fix

- Keep a checked-in seed script for staging verification rows so any
  rebuild is one command.

## Prevention

- [x] Staging rebuilt from migrations (done)
- [ ] Checked-in staging seed script (follow-up)

## Related Issues

- The fix it blocked:
  `Backend_and_API/ZCHPC-2026-09-29-employee-id-vo-rejects-legacy-h-ids.md`

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** ~30 min
