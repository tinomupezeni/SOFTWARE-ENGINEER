# PR #12's PG15->PG16 db image bump crash-looped the production database

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Production (restk-vps)
**Severity:** Critical
**Status:** Workaround applied — root fix (the actual major-version upgrade) deferred

## Summary
PR #12's `deploy/production/docker-compose.yml` bumped the `db` service
from `pgvector/pgvector:pg15` to `pgvector/pgvector:0.7.4-pg16`. While
manually debugging the deploy-script truncation bug (see the sibling
bug-log entry), that image bump was exercised for the first time against
the real production data volume and immediately crash-looped: Postgres
refuses to start a data directory initialized by one major version under
a different major version's server binary. `maricho-api` went unhealthy
as a result. Rolled the `db` image back to `pgvector/pgvector:pg15`
against the same (untouched) data volume to restore service; the actual
PG16 upgrade still needs to happen, deliberately, as its own task.

## Symptoms
- `docker ps` showed `maricho-production-db-1` status `Restarting (1)`
  on a tight loop.
- `docker logs maricho-production-db-1`:
  ```
  FATAL:  database files are incompatible with server
  DETAIL:  The data directory was initialized by PostgreSQL version 15,
  which is not compatible with this version 16.3 (Debian 16.3-1.pgdg120+1).
  ```
- `maricho-api` flipped to `unhealthy` shortly after (its DB connection
  pool lost its target).
- `maricho-frontend` stayed `healthy` throughout, since most of its own
  routes don't depend on a live DB connection.

## Environment Details
- **Server/Host:** restk-vps
- **Services Affected:** `maricho-production-db-1`, `maricho-api`
- **Time First Observed:** 2026-11-17, while manually running
  `docker compose up -d db redis` to debug why the automated deploy
  script produced no visible output for that step.

## Investigation Steps

### 1. Initial Diagnosis
`docker ps` showed the new image tag (`pgvector/pgvector:0.7.4-pg16`) on
a restarting container. `docker logs` gave the exact, unambiguous FATAL
reason on the first read.

### 2. Root Cause Analysis
Confirmed the existing `maricho_postgres_data` named volume was created
under PG15 (per the error) and was never migrated. A Postgres major
version bump is not image-swappable — it requires `pg_dump`/restore into
a fresh PG16 data directory, or `pg_upgrade` run against the old one,
with the old binaries still present to do the conversion. Neither
happened; the compose file's image tag was simply changed as part of
PR #12's broader pgvector-search feature work, without anyone — reviewer
or deploy operator — connecting "this bumps a Postgres major version"
to "this needs an explicit upgrade procedure, not just a deploy."

### 3. Key Findings
- The data volume itself (`maricho-production_maricho_postgres_data`) was
  never touched or corrupted — Postgres fails this check before writing
  anything, so reverting the image tag and recreating the container
  against the same volume was fully safe.
- `maricho-production-db-1`'s Docker network (`maricho-production_maricho_internal`)
  is a project-scoped network with no published ports; only `maricho-api`
  and `maricho-production-redis-1` are on it. Confirmed no other tenant on
  this shared VPS (TESE marketplace, Swap-O-Sell, MLMS, Lakeisha Cakery,
  ProjectFlow, etc.) could have been affected by this db instance being
  down.
- A fresh pre-deploy `pg_dump` backup existed (taken automatically by
  `deploy.sh` moments before the crash loop began), as a safety net that
  ultimately wasn't needed since the volume was intact.

## Root Cause
A Postgres major-version image bump (`pg15` -> `0.7.4-pg16`) was shipped
in `docker-compose.yml` as an ordinary config change, with no
accompanying migration step, and nothing in the deploy pipeline (or the
PR review that introduced it) flagged that a Postgres major-version
change needs an explicit upgrade procedure rather than a plain image
swap.

## Prevention / Rule
**Guardrail:** Add a pre-flight check to `deploy.sh`, before it ever runs
`docker compose up` on `db`: compare the running container's Postgres
major version (`docker compose exec db psql -tAc "SHOW server_version"`,
or simpler, read `PG_VERSION` from the data directory) against the major
version implied by the compose file's new `db` image tag. If they differ,
abort with an explicit error naming both versions and pointing at a
written upgrade procedure, rather than attempting `up -d` at all.

This closes the gap because the actual failure here was "nothing in the
pipeline distinguishes an ordinary image bump from a major-version
upgrade that needs special handling" — a version-compatibility pre-flight
check converts that into a named, loud failure before any container is
touched, instead of a crash loop discovered after the fact.

## Solution

### Immediate Fix
```bash
# On the VPS, inside the repo's deploy/production directory:
sed -i 's#image: pgvector/pgvector:0.7.4-pg16#image: pgvector/pgvector:pg15#' docker-compose.yml
docker compose --env-file /home/winstontino/apps/maricho/.env up -d --no-build db
```
Confirmed `maricho-production-db-1` returned to `healthy` on `pg15`
against the untouched data volume, `maricho-api` returned to `healthy`,
and the public site (`https://maricho.restk.tech/health/live`,
`https://maricho.restk.tech/`) responded normally again.

### Long-term Fix
The actual PG15->PG16 upgrade (needed for whatever PR #12's pgvector
work assumes `0.7.4-pg16` provides) must be planned as its own task:
`pg_dump` the PG15 database, stand up a fresh PG16 data directory,
restore into it, verify row counts/`pgvector` extension/HNSW index
integrity, then cut over — not a routine `docker-compose.yml` edit during
an unrelated feature deploy. Deferred pending explicit sign-off; `main`'s
`docker-compose.yml` still specifies `0.7.4-pg16` and must not be deployed
as-is until that upgrade has actually happened.

## Prevention
- [ ] Configuration changes needed (the version-compatibility pre-flight
      check in `deploy.sh`, not yet implemented)
- [ ] Monitoring/alerts to add (alert on any container entering a
      restart-loop state, independent of this specific cause)
- [ ] Documentation to update (a written PG15->PG16 upgrade runbook)
- [x] Code changes required (emergency rollback applied; the real fix —
      the data upgrade itself — is still outstanding)

## Related Issues
- `DevOps_and_Infrastructure/MARITCHO-2026-11-17-deploy-script-silently-truncated-leaving-prod-stale.md`
  (the bug being debugged when this incident was triggered)

## References
- `deploy/production/docker-compose.yml`
- PR `Rest-creator/MARITCHO#12` (introduced the `0.7.4-pg16` bump as part
  of its broader pgvector semantic search work)

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** ~10 minutes from crash-loop to restored service; the root upgrade remains outstanding
