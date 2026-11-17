# deploy.sh removal of unconditional `docker compose down` stops cycling degraded db/redis containers

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** Medium
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
On `main`, `deploy/production/deploy.sh` ran `docker compose down --remove-orphans` unconditionally,
immediately followed by `docker compose up -d --no-build` (all services) — guaranteeing every
container, including `db`/`redis`, was freshly recreated on every deploy regardless of its prior
health. On `pr-12`, the `down` step is removed entirely; `db`/`redis` are now brought up via
`docker compose up -d --no-build db redis` (no `--remove-orphans`), while only `api`/`frontend` get
`--remove-orphans` treatment later in the script. Since `db`/`redis` use fixed image tags with no
`${APP_VERSION}` interpolation (unlike `api`/`frontend`), and `docker compose up -d` only recreates a
container whose resolved config differs from the running one, a `db` or `redis` container left
degraded-but-"Up" from a prior incident would no longer get cycled by a subsequent deploy.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- If `db`/`redis` is ever left in a degraded-but-responsive state (zombie process, exhausted
  connections, corrupted-but-responsive state), re-running the new deploy script leaves it degraded
  instead of cycling it, whereas the old script's unconditional `down` would have forced a fresh
  container.

## Environment Details
- **Server/Host:** Production VPS (deploy target)
- **Services Affected:** `db` (pgvector/postgres), `redis`
- **Related Components:** `deploy/production/deploy.sh`, `deploy/production/docker-compose.yml`
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding claimed the removal of the unconditional `docker compose down --remove-orphans`
step, combined with db/redis using fixed (non-version-bumped) image tags, removes the forced-recreation
safety net for those two stateful services specifically.

### 2. Root Cause Analysis
- Confirmed via `git show main:deploy/production/deploy.sh`: the pre-PR script ran
  `docker compose down --remove-orphans` unconditionally before `docker compose up -d --no-build`
  (no service list — every service).
- Confirmed via `git diff main...pr-12 -- deploy/production/deploy.sh`: the `down` line is deleted. In
  its place: `docker compose up -d --no-build db redis` (no `--remove-orphans`), followed by a
  db-health-check loop, then `docker compose up -d --no-build --remove-orphans api frontend`.
- Confirmed via `git show pr-12:deploy/production/docker-compose.yml`:
  `db: image: pgvector/pgvector:0.7.4-pg16` and `redis: image: redis:7-alpine` — both fixed tags with
  no `${APP_VERSION}` interpolation, whereas `api`/`frontend` use
  `image: maricho-backend:${APP_VERSION:?...}` / `maricho-frontend:${APP_VERSION:?...}`, which changes
  every deploy.
- Since `docker compose up -d` (without `--force-recreate`) only recreates a service when its resolved
  config differs from the running container's, and db/redis's config never changes between deploys, a
  degraded-but-"Up" db/redis container is left untouched.
- Mitigating factor found during verification: the new script does add a pre-deploy `pg_dump` backup
  gated on `pg_isready`, and a `db_ready` readiness loop before proceeding — these catch a fully-dead
  db (it would fail the readiness gate and abort deployment) but do not address a container that is
  "Up" and responsive enough to pass `pg_isready` while still being in a bad state that only a full
  container recreation would clear.

### 3. Key Findings
- The asymmetry (api/frontend forced to refresh via version tag, db/redis left to persist indefinitely
  across deploys) was likely an intentional performance/safety tradeoff (avoiding needless db/redis
  restarts that could interrupt active connections) but removes a safety net without an explicit
  replacement for the specific "degraded but responsive" failure mode.

## Root Cause
The deploy script's db/redis handling was changed from "always recreate" to "recreate only on config
change" to avoid unnecessary restarts of stateful services, but no equivalent health-based recreation
trigger (e.g. forcing a restart when a container is unhealthy per its Docker healthcheck, not just
when its config changed) was added to replace the blanket safety net that was removed.

## Prevention / Rule
**Guardrail:** Add an explicit health check gate in `deploy.sh` that inspects
`docker compose ps db redis` for `healthy`/`unhealthy` status (both have healthchecks defined in
`docker-compose.yml`) and runs `docker compose up -d --force-recreate db redis` specifically when a
container reports unhealthy, before proceeding with the rest of the deploy — restoring forced recovery
for a genuinely degraded container without reintroducing the cost of always recreating a healthy one.

This closes the Root Cause gap: it keeps the intended "don't needlessly restart a healthy stateful
service" behavior while restoring exactly the safety net (recovery from a degraded-but-responsive
state) that the removed unconditional `down` used to provide unconditionally.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed operational-risk regression found during review of
PR #12; it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Add the health-gated `--force-recreate` step described in the guardrail above.
- Document this tradeoff explicitly in `deploy/production/README.md` so operators know a manual
  `docker compose restart db` (or similar) may be needed if a deploy doesn't resolve a suspected db
  issue.

## Prevention
- [ ] Configuration changes needed — none
- [x] Monitoring/alerts to add — alert on db/redis container health status so a degraded-but-running
      container is caught independent of deploy cadence
- [ ] Documentation to update — note the new db/redis persistence behavior in README.md (not yet done)
- [x] Code changes required — add health-gated force-recreate for db/redis in deploy.sh (not yet
      implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that changed this script.
- Related to the pgvector-image fix recorded in
  `DevOps_and_Infrastructure/MARITCHO-2026-11-17-production-db-missing-pgvector-extension.md`, same
  area of the deploy pipeline.

## References
- `deploy/production/deploy.sh` (before: `git show main:deploy/production/deploy.sh`; after:
  `git show pr-12:deploy/production/deploy.sh`)
- `deploy/production/docker-compose.yml` (image tag scheme for db/redis vs api/frontend)
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
