# Notifications worker crash-looping on Redis read-only replica

**Date:** 2026-10-06
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`, 209.209.42.142)
**Severity:** High
**Status:** Resolved (workaround — worker, beat, green backend all on master; durable Sentinel fix still open)

## Summary
`hbec-notifications-worker` is crash-looping with `redis.exceptions.ReadOnlyError: You can't write against a read only replica.` The worker resolved Redis to the replica instead of the master — the classic Sentinel-failover aftermath: reads keep working so everything else looks healthy, while every write path dies. The `bg-student-beat` / `bg-student-worker` unhealthy flags are suspected to share the cause.

## Symptoms
- `hbec-notifications-worker` state `Restarting (1)`, restart loop ~44s.
- Traceback ends in `redis/connection.py read_response` raising `ReadOnlyError`.
- Reads platform-wide unaffected (all other services report healthy).

## Environment Details
- **Server/Host:** gpu-ndime (VPS, up 96 days)
- **Services Affected:** hbec-notifications-worker (Celery; fan-out + reply-email delivery stalled while down)
- **Related Components:** redis (master), redis-replica, redis-sentinel, hbec-notifications-backend
- **Time First Observed:** 2026-10-06 ~07:50 UTC (during read-only VPS appreciation pass)

## Investigation Steps

### 1. Initial Diagnosis
`docker ps` showed the worker as the only restarting container in the `hbec-*` stack; `docker logs --tail` gave the `ReadOnlyError` immediately. No code change preceded it — this is runtime topology, not a deploy.

### 2. Root Cause Analysis
To be confirmed: which address the worker's Redis client resolved (env `REDIS_URL` vs Sentinel discovery), current Sentinel master view (`SENTINEL masters` / `get-master-addr-by-name`), and whether a failover happened recently (Sentinel logs). Prior art: `HBEC-2026-07-13-redis-sentinel-500-error.md` (client-config facet of the same Sentinel setup) and the known Sentinel-failover-readonly failure mode already documented in HBEC's CLAUDE.md.

### 3. Key Findings
- Failure is client-side pinning, not server-side: the replica is correctly read-only; the worker is simply talking to the wrong node.
- Blast radius is write paths only, which is why monitoring stayed green.

## Root Cause
Confirmed: a Sentinel failover promoted `redis-replica` to master (Sentinel `get-master-addr-by-name` → `redis-replica:6379`; old `redis` is now its healthy slave, replicating, ~1s lag). The notifications service connects via hardcoded `REDIS_URL=redis://redis:6379/3` with no Sentinel discovery — in code (`init_redis` uses plain `aioredis.from_url`; the harness's Sentinel helpers were deliberately dropped) and in Celery broker config. Post-failover, every write lands on a read-only slave. Verified live-vs-idle first: Caddy routes all traffic to the uncolored legacy containers; `active_color=blue` is not wired into Caddy, so blue AND green are both idle (green freshest, `sha-e44223f`).

## Prevention / Rule
**Guardrail:** every Celery worker entrypoint must resolve the Redis master through Sentinel at startup (never a hardcoded node address) and crash on boot if the resolved node answers `READONLY` to a `SET` probe — fail-fast on boot rather than crash-looping on the first real write.

A client that re-resolves the master on `ReadOnlyError` (drop pool, re-discover, single retry) would close the remaining window without operator action.

## Solution

### Immediate Fix
Applied 2026-10-06 ~08:05 UTC on GREEN ONLY (idle branch): recreated
`hbec-notifications-backend-green` with `REDIS_URL=redis://redis-replica:6379/3`
via a temporary compose override (`/tmp/hbec-green-redis-override.yml` on the
VPS — NOT in the repo), leaving live (uncolored) and blue untouched (start
times verified unchanged). Verified: container healthy + live SET/GET/DEL
write probe against the master (scratch key removed). Override needed
`TAG_BLUE/TAG_GREEN/TAG_ACTIVE` + `*_ACTIVE` service URLs inline because
`/opt/hbec/.env` doesn't carry them; values mirrored from running containers.

```bash
# Recreate green only (from /opt/hbec)
TAG_BLUE=prod-promote-6a151782 TAG_GREEN=sha-e44223f TAG_ACTIVE=prod-promote-6a151782 \
STUDENT_BACKEND_URL_ACTIVE=http://student-backend:8000 \
HARNESS_SERVICE_URL_ACTIVE=http://harness-blue:8080 \
STUDENT_SERVICE_URL_ACTIVE=http://student-backend:8000 \
SCHOOLS_SERVICE_URL_ACTIVE=http://schools-backend:8000 \
docker compose -f docker-compose.production.yml -f /tmp/hbec-green-redis-override.yml \
  --profile color-green up -d notifications-green
```

Caveat: this repoints at a hostname, not through Sentinel — the NEXT failover
breaks it identically. Durable fix (service Sentinel-aware: app client +
Celery `sentinel://` broker, `REDIS_SENTINEL_*` in compose) still open — take
it up as follow-up work.

Update 2026-10-06 ~08:10 UTC — worker + beat restored too. A bare restart
could never have worked (same hardcoded URL → same crash), so both were
recreated with the same override (appended `notifications-worker` and
`notifications-beat` stanzas to `/tmp/hbec-green-redis-override.yml`,
`--profile workers up -d`). The beat had been failing silently as well —
3,420 `SchedulingError: ... read only replica` lines in 30 min behind a green
healthcheck (it only checks the process cmdline, never a broker write).
Verified after: worker `running healthy`, connected to
`redis://redis-replica:6379/3`; beat scheduling clean; 12 tasks
received+succeeded in 2 min, zero errors. Note: prod runs `sha-e44223f`,
which predates the reply-email worker task, so no stuck `QUEUED` email
fallout was possible here.

```bash
# Diagnose (read-only)
ssh hbca-vps "docker exec hbec-redis-sentinel redis-cli -p 26379 SENTINEL masters"
ssh hbca-vps "docker exec hbec-redis redis-cli INFO replication | grep -e role -e connected_slaves"
ssh hbca-vps "docker logs --tail 30 hbec-notifications-worker"
```

### Long-term Fix
- Sentinel-aware Redis clients everywhere a worker writes (audit `REDIS_URL` vs sentinel discovery per service).
- Alert on `ReadOnlyError` in worker logs (it is the precise signature of this failure mode) rather than on container restarts alone.

## Prevention
- [ ] Startup master-resolution + READONLY probe in worker entrypoints
- [ ] Alert rule: `ReadOnlyError` in any backend log
- [ ] Document the Sentinel failover runbook (check master view → restart pinned workers → verify)
- [ ] Code changes required (client re-resolution on ReadOnlyError)

## Update 2026-10-06 (later the same day) — the override didn't cover `blue`, and bit again during the real cutover

The override was formalized into a tracked file,
`docker/redis-failover-20261006.override.yml`, listing `notifications-green`,
`notifications-worker`, `notifications-beat` — written while blue was still
idle and green was the thing that mattered. Hours later, the real
blue/green cutover happened (`active_color` flipped to `blue`) and
`notifications-backend-blue` — now the live, user-facing container — was
recreated as part of the cutover's normal image rebuild, **without** this
override applied (it has no `notifications-blue` entry at all). It came up
healthy (the healthcheck only checks the process, same gap noted above) and
silently went live pointed at `redis://redis:6379/3`, the dead master, for
the entire window between cutover and this being caught.

Caught during the cutover itself (not by a user report): recreating the
singleton `notifications-worker`/`notifications-beat` as part of the
same cutover's follower handoff hit the exact same `ReadOnlyError`
immediately, which prompted re-checking `notifications-backend-blue`
directly — confirmed it had the same wrong `REDIS_URL`.

**Fixed**: added a `notifications-blue` stanza to the override (same fix,
`redis://redis-replica:6379/3`), copied the override file to the VPS (it had
never been copied there at all — it only existed in the local working
tree), and recreated `notifications-backend-blue` with both compose files.
Verified healthy with the correct `REDIS_URL` immediately after.

**This is the same root cause demonstrating the same lesson twice in one
day**: a per-color override file needs an entry for every color that can
go live, not just whichever one is live when the override is written, and
a hand-maintained VPS-only file (like `.env`) needs an explicit step to
actually reach the VPS — "I edited it locally" is not "it's applied."
Neither gap is closed by the durable Sentinel fix either; both apply to
whatever stopgap exists for as long as `notifications` stays
Sentinel-unaware.

## Related Issues
- `DevOps_and_Infrastructure/HBEC-2026-07-13-redis-sentinel-500-error.md` (same Sentinel setup, client-config facet)
- HBEC CLAUDE.md "side effect must not fail..." / Sentinel failover notes

## References
- VPS: `/opt/hbec` (`docker-compose.production.yml`), live stack `hbec-*` + `bg-*`

---

**Resolved By:** Muse Spark (opencode) + Tino — workaround (hostname repoint, all three services)
**Time to Resolution:** ~25 min (diagnosis to verified task flow)
