# Production DB image missing pgvector extension, crash-looping API

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The production `db` service in `deploy/production/docker-compose.yml` ran
plain `postgres:15`, which does not include the `pgvector` extension. A
pending Alembic migration (`d8f3a1c2e5b7_add_pgvector_search.py`) that runs
`CREATE EXTENSION IF NOT EXISTS vector` on every container start therefore
failed every time, putting `maricho-api` into a permanent crash-restart
loop in production.

## Symptoms
- `maricho-api` container status: `Restarting (1) 5 seconds ago`, repeating
  for hours.
- `docker logs maricho-api` showed `sqlalchemy.exc.DBAPIError: ... extension
  "vector" is not available` during alembic upgrade on container start.
- Frontend/API traffic to the production stack likely degraded while the
  API never stabilized.

## Environment Details
- **Server/Host:** restk-vps (server1.tesemarket.com)
- **Services Affected:** `maricho-api` (backend), indirectly `maricho-frontend`
- **Related Components:** `maricho-production-db-1` (postgres), Alembic
  migration `d8f3a1c2e5b7_add_pgvector_search.py`
- **Time First Observed:** 2026-11-17, during a routine VPS check; container
  had been restarting for ~9 hours prior.

## Investigation Steps

### 1. Initial Diagnosis
Ran `docker ps -a` on the VPS and noticed `maricho-api` in a `Restarting`
state while `maricho-production-db-1` showed healthy.

### 2. Root Cause Analysis
```bash
docker logs --tail 100 maricho-api
```
Traceback pointed to the pgvector migration's `CREATE EXTENSION` statement
failing with `extension "vector" is not available`.

### 3. Key Findings
- `maricho-production-db-1` was running image `postgres:15` (official,
  no pgvector).
- The local repo's `deploy/production/docker-compose.yml` already had an
  uncommitted, unstaged fix changing the image to `pgvector/pgvector:pg15`
  — the fix had been made but never deployed.

## Root Cause
Vector-search support was added to the application (migration +
presumably embeddings code) without updating the production Postgres image
to one that ships the `pgvector` extension. The compose file and the
migration drifted apart.

## Prevention / Rule
**Guardrail:** Add a CI check (or a pre-deploy step in
`deploy/production/deploy.sh`) that runs `docker compose exec db psql -c
"SELECT * FROM pg_available_extensions WHERE name='vector'"` and fails the
deploy if the extension isn't available, before migrations run. This turns
an image/migration mismatch into a fast, explicit pre-flight failure
instead of a silent crash loop discovered later.

This closes the gap because the deploy script already gates on alembic
head state (`deploy.sh` checks `alembic current`/`alembic heads`) — adding
an extension-availability check at the same gate catches this exact class
of drift (migration requires an extension the DB image doesn't provide)
before `docker compose up` is considered successful.

## Solution

### Immediate Fix
Committed the pending local change and redeployed via the project's own
deploy script:
```bash
git commit -m "fix: use pgvector-enabled postgres image in production compose" \
  deploy/production/docker-compose.yml

MARICHO_VPS=restk-vps \
MARICHO_DOMAIN=maricho.restk.tech \
MARICHO_WS_URL=wss://maricho.restk.tech \
MARICHO_REMOTE_DIR=apps/maricho \
bash deploy/production/deploy.sh
```
`deploy.sh` rebuilt backend/frontend images, uploaded the updated compose
file, ran `docker compose down && docker compose up -d` (volumes
preserved), and verified alembic was at head and all containers healthy.
Confirmed post-deploy: `maricho-production-db-1` now runs
`pgvector/pgvector:pg15`, and all four containers (`db`, `redis`, `api`,
`frontend`) report `healthy`.

### Long-term Fix
Add the extension-availability pre-flight check described above to
`deploy/production/deploy.sh` so a future migration that needs a new
Postgres extension fails loudly at deploy time instead of crash-looping in
production.

## Prevention
- [ ] Add extension pre-flight check to `deploy.sh`
- [x] Configuration changes needed (db image switched to
      `pgvector/pgvector:pg15`)
- [ ] Monitoring/alerts to add (alert on container restart-loop, e.g. via
      `docker events` or a healthcheck-based alert)
- [ ] Documentation to update (note pgvector requirement in deployment docs)

## Related Issues
None tracked.

## References
- `deploy/production/docker-compose.yml`
- `backend/migrations/versions/d8f3a1c2e5b7_add_pgvector_search.py`

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** ~20 minutes from diagnosis to verified healthy deploy
