# Production Postgres collation version mismatch (glibc 2.41 vs 2.36)

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Production (`restk-vps`, `maricho-production-db-1`)
**Severity:** Medium
**Status:** Investigating

## Summary
During the deploy of PR #14 (`deploy/production/deploy.sh`), both the
pre-deploy pg_dump backup step and the Alembic migration step logged:

```
WARNING:  database "maricho" has a collation version mismatch
DETAIL:  The database was created using collation version 2.41, but the
operating system provides version 2.36.
HINT:  Rebuild all objects in this database that use the default
collation and run ALTER DATABASE maricho REFRESH COLLATION VERSION, or
build PostgreSQL with the right library version.
```

This means the glibc collation library the `maricho` database was
originally created against (2.41) no longer matches the glibc version the
`pgvector/pgvector:pg15` container's OS now provides (2.36) — most likely
because the Postgres image was updated/rebuilt with an older base image at
some point, or the host's glibc changed under it.

## Symptoms
- Not an active user-facing symptom yet — surfaced only as a WARNING
  during backup and migration, deploy still completed successfully
  (migrations applied, health checks passed).
- No query failures or incorrect results observed so far.

## Environment Details
- **Server/Host:** Production VPS (`restk-vps`)
- **Services Affected:** `maricho-production-db-1`
  (`pgvector/pgvector:pg15`)
- **Related Components:** Any index or query relying on the database's
  default collation for text ordering/comparison (`ORDER BY` on text
  columns, unique constraints on text, `LIKE`/range queries)
- **Time First Observed:** 2026-11-24, during the PR #14 production deploy

## Investigation Steps

### 1. Initial Diagnosis
Noticed the WARNING twice in the deploy script's own output (backup step
and migration step) while deploying PR #14's merge commit
(`56e0a4f8a636`).

### 2. Root Cause Analysis
Not yet root-caused to a specific event (e.g. a base-image bump on the
`pgvector/pgvector:pg15` image, or a host-level glibc change) — this entry
records the finding so it isn't lost, pending a dedicated investigation.

### 3. Key Findings
- The mismatch is a stale cached collation version recorded in
  `pg_database.datcollversion`, not (necessarily) data corruption yet —
  but any index or constraint built under the old collation version is at
  risk of silently disagreeing with how Postgres now sorts/compares text,
  which can produce wrong query results or a corrupted unique/btree index
  if left unaddressed.

## Root Cause
Not yet confirmed. Suspected: the Postgres container's base OS image was
rebuilt/updated with a newer glibc (2.41) at some point after the database
was first initialized under glibc 2.36, or vice versa — Postgres caches
the collation version at creation/`ALTER COLLATION ... REFRESH` time and
only warns when it later detects a mismatch against the OS's current
library.

## Prevention / Rule
**Guardrail:** pin the exact Postgres image digest (not just the `pg15`
tag) for `maricho-production-db-1` so an upstream base-image rebuild can't
silently change the underlying glibc version under a running database
without a deliberate, reviewed bump.

## Solution

### Immediate Fix
None applied yet — this is a WARNING, not a hard failure, and the fix
(`REINDEX`-ing affected objects then `ALTER DATABASE maricho REFRESH
COLLATION VERSION`) should be done deliberately with a maintenance window,
not as a side effect of an unrelated feature deploy.

### Long-term Fix
1. Identify every index/constraint built on a text column using the
   database's default collation (`\d` on tables, or query
   `pg_depend`/`pg_collation`).
2. `REINDEX` those objects under the current (correct) collation.
3. Run `ALTER DATABASE maricho REFRESH COLLATION VERSION` to clear the
   cached mismatch.
4. Pin the Postgres image by digest going forward (see guardrail above).

## Prevention
- [ ] Configuration changes needed (pin Postgres image by digest)
- [ ] Monitoring/alerts to add (surface this WARNING from deploy logs to
      an actual alert instead of relying on someone reading deploy output)
- [ ] Documentation to update
- [x] Code changes required (not yet — tracked here first)

## Related Issues
- Surfaced during the deploy of GitHub PR Rest-creator/MARITCHO#14

## References
- Deploy output from `deploy/production/deploy.sh`, 2026-11-24, deploying
  commit `56e0a4f8a636`
- PostgreSQL docs: https://www.postgresql.org/docs/current/sql-alterdatabase.html

---

**Resolved By:** Not yet resolved — logged by Claude Code during the PR #14 deploy
**Time to Resolution:** Open
