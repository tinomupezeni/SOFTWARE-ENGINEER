# Full backup omitted service databases

**Date:** 2026-10-31
**Project:** HBEC
**Environment:** Production (`hbca-vps`)
**Severity:** High
**Status:** Workaround Applied

## Summary
The full disaster-recovery script hard-coded dumps of only `hbec_student`, `hbec_admin`, and `harness_db`. It omitted live LiteLLM, notifications, and schools databases, as well as the maintenance databases. The script now discovers every non-template database on both PostgreSQL instances and validates each custom-format dump before archiving.

## Symptoms
- The former full archive could not restore all live service databases.
- The separate nightly SQL job mirrored four databases, still omitting `hbec_litellm`, `hbec_notifications`, and `hbec_schools`.
- Backup success depended on a fixed database list that drifted from production.

## Environment Details
- **Server/Host:** `hbca-vps` and external mirrors at `159.198.42.231` and `93.127.143.153`.
- **Services Affected:** PostgreSQL backup for all HBEC services.
- **Related Components:** `scripts/backup-hbec.sh`, `hbec-postgres`, `hbec-harness-db`.
- **Time First Observed:** 2026-10-31 backup preflight.

## Investigation Steps

### 1. Initial Diagnosis
Compared `pg_database` on both live PostgreSQL instances with the hard-coded dump commands in the deployed script and the archive contents.

### 2. Root Cause Analysis
The backup script listed three databases by name and was not updated when new service databases were introduced. No coverage check compared backup entries to the live catalog.

```bash
ssh hbca-vps 'docker exec hbec-postgres psql -X -v ON_ERROR_STOP=1 -U hbec -d postgres -Atc "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname"'
ssh hbca-vps 'docker exec hbec-harness-db psql -X -v ON_ERROR_STOP=1 -U harness -d postgres -Atc "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname"'
```

### 3. Key Findings
- The main instance has eight non-template databases; the harness instance has two.
- The replacement script created ten non-empty custom-format dumps, each validated by `pg_restore --list`, plus role globals.
- The new full archive passed `tar -tzf` and has SHA-256 `9fc2022c3dc0b386287f2f33bbe678b6e4abd85fdb39aebb224d1b00f8480c30` on the source and both mirrors.

## Root Cause
Backup coverage was maintained as a stale manual list instead of being derived from the live database catalog and checked before success.

## Prevention / Rule
**Guardrail:** Full backups must enumerate every non-template database on each configured PostgreSQL instance and fail if any dump is empty or unreadable by `pg_restore --list`; mirror checksums must match before success is reported.

## Solution

### Immediate Fix
Updated and installed `scripts/backup-hbec.sh`, then completed a fresh 2026-10-31 full backup containing all ten databases, Redis, Qdrant snapshots, media, and configuration. Both mirrors hold byte-identical copies with mode `600`.

```bash
bash -n scripts/backup-hbec.sh
ssh hbca-vps 'sudo -n /opt/hbec/scripts/backup-hbec.sh'
```

### Long-term Fix
Keep database discovery and archive-to-live-catalog comparison in the scheduled backup path; check the next cron run and periodically rehearse restore.

## Prevention
- [x] Dynamic coverage and dump validation installed.
- [x] Full archive verified on both external VPSes.
- [ ] Verify the next scheduled cron run and perform a restore drill.

## Related Issues
- `DevOps_and_Infrastructure/HBEC-2026-10-31-full-backup-cron-executable-bit-regressed.md`

## References
- `scripts/backup-hbec.sh`
- `/opt/hbec/backups/hbec_backup_20261031_060625.tar.gz`

---

**Resolved By:** Codex
**Time to Resolution:** Same session
