# DB Connection Pool Sizing (30/instance) Caps Horizontal Scaling at ~3 API Replicas With No Pooler in Front

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
`app/database.py` configures the async SQLAlchemy engine with
`pool_size=20, max_overflow=10` — i.e. up to 30 live Postgres connections
per running API instance. This value was chosen (per the SRS/engineering
standards) to prevent *starvation within one instance*, but nothing
accounts for what happens once the API is scaled horizontally (multiple
containers/replicas behind a load balancer), which the containerization
work this same day explicitly made possible. Postgres 15's default
`max_connections` is 100. Three API replicas alone (3 × 30 = 90) would
already approach that ceiling before counting Postgres's own reserved
superuser connections, `alembic`/psql/monitoring connections, or a second
service (e.g., a future background-worker tier) also connecting.

## Symptoms
- `app/database.py`: `pool_size=20, max_overflow=10`, no awareness of how
  many replicas might run concurrently.
- `docker-compose.yml`'s `db` service uses the Postgres 15 image with no
  `max_connections` override (so it's at the default, 100).
- No connection pooler (e.g., PgBouncer) sits between the API and
  Postgres — every instance's pool talks to Postgres directly.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/database.py`, `backend/docker-compose.yml`
- **Related Components:** the containerization work done this same day
  (`Dockerfile`, `api` service) makes running multiple replicas of the
  `api` service straightforward — this finding is what would actually
  happen if someone did that today
- **Time First Observed:** 2026-09-11, scalability review requested
  directly by the user, shortly after containerizing the API

## Investigation Steps

### 1. Initial Diagnosis
Asked "is this scalable" right after having just made the API easy to run
as multiple replicas — checked whether the DB side was designed with that
in mind.

### 2. Root Cause Analysis
`pool_size=20, max_overflow=10` was set to satisfy
`engineering_standards.md`'s connection-pooling requirement, which was
written and verified purely in terms of a *single* instance not starving
itself under a burst of concurrent requests (see RSK-002 in
`docs/project_plan.md`). Nobody has yet needed more than one API instance,
so the multi-instance math was never worked through.

### 3. Key Findings
- 3 replicas × 30 = 90 connections, leaving only 10 of Postgres's default
  100 `max_connections` for anything else (migrations, psql, a future
  worker tier) — in practice this would start failing with "too many
  clients" well before 3 full replicas under load.
- This is a config/ops concern, not a code bug — nothing is wrong with a
  single instance today.

## Root Cause
Connection-pool sizing was tuned for the single-instance case that has
existed until now; horizontal scaling wasn't yet a real deployment option
until this session's containerization work, so the two were never
reconciled.

## Prevention / Rule
**Guardrail:** Document the connection-budget formula (`replica_count × (pool_size + max_overflow) ≤ max_connections`) directly alongside the pool-size config, and re-check it explicitly any time either the replica count or the pool size changes.

The original sizing was correct for the single-instance case it was designed for; the gap was that nothing forced a re-check when horizontal scaling became newly possible.

## Solution

### Immediate Fix
Put the three options (lower pool size, raise `max_connections`, add
PgBouncer) to the user; answer was to lower the per-instance pool and
document the budget rather than add infrastructure (PgBouncer) or accept
the memory cost of a higher `max_connections` before any real multi-
replica deployment exists.

Applied, same day:
- `app/database.py`: `pool_size` dropped from 20→10, `max_overflow` from
  10→5 (30→15 max connections/instance), with a comment explaining the
  budget math and pointing at `engineering_standards.md`.
- `docs/engineering_standards.md` §3: documented the connection-budget
  formula (`replica_count × (pool_size + max_overflow) ≤
  max_connections`) alongside the new pooling numbers, so this is a
  reusable rule, not just a one-off tuning.
- Propagated the new `pool_size=10, max_overflow=5` figures into the three
  other docs that quoted the old `20`/`10` values as the standard
  (`docs/architecture/adr/001-core-tech-stack.md`, `docs/requirements/srs.md`,
  `docs/project_plan.md` RSK-002) so they stay consistent with the actual
  config instead of silently drifting.

Verified: `ruff check .` / `mypy .` clean (40 files); full suite green (90
passed, 92.75% coverage) — no test relies on the specific pool size, and a
15-connection pool is still generous for the test suite's concurrency.

At 15/instance, up to ~6 replicas fit under Postgres's default
`max_connections=100` with 10 connections of headroom for
migrations/psql/monitoring — double the previous ~3-replica ceiling,
without adding any new infrastructure.

### Long-term Fix
Done for the current single-instance deployment. If/when a real
multi-replica deployment is actually planned, re-run the budget formula
against the target replica count — if that number exceeds what a further
pool reduction can reasonably support, PgBouncer (or raising
`max_connections`) becomes the right next step then, not now.

## Prevention
- [x] Lowered the per-instance pool and documented the connection budget
  in `docs/engineering_standards.md`
- [x] Propagated the new numbers to every doc that quoted the old ones,
  so they don't silently drift out of sync with the real config again

## Related Issues
- Enabled/surfaced by this same day's containerization work
  (`BACK-006`), which is what makes multi-replica deployment newly
  practical

## References
- `docs/engineering_standards.md` §3 — connection pooling requirement
- `docs/project_plan.md` — RSK-002 "Connection Starvation"

---

**Resolved By:** Claude Code (architecture-review-to-fixes session), scoping
decision confirmed by the user
**Time to Resolution:** Same day, follow-up session
