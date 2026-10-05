# Redis stuck as a read-only replica since 2026-09-25 — Sentinel promoted correctly, but every service still hardcodes the old hostname

**Date:** 2026-10-05
**Project:** HBEC
**Environment:** Production (VPS `/opt/hbec`) — affects every environment that
shares this Redis: the real, currently-live unsuffixed production containers,
*and* the separate, not-yet-cut-over blue/green pair (see correction below)
**Severity:** High
**Status:** Workaround Applied (Sentinel-orchestrated failover restored the
hardcoded `redis` hostname as a writable master — fixes every service
immediately, including ones with no Sentinel support in their own code. The
durable fix, Sentinel-aware clients for the 3 services that support it, is
still pending — see Long-term Fix.)

## Correction (same-day, found while scoping the fix)
Everything below originally assumed `student-backend-blue` *is* production.
It is not. The live `docker/caddy/Caddyfile` routes every public domain
(`student.hbca.tech`, `admin.hbca.tech`, etc.) at a third, **unsuffixed**
set of containers (`hbec-student-backend`, `hbec-admin-backend`,
`hbec-harness`, ...) running the same `prod-promote-6a151782` image as
`-blue`. The real blue/green cutover (`render-caddyfile.sh` writing
color-suffixed upstreams) has never actually been executed — `-blue`/`-green`
are a separate, inert pair only reachable via `staging-*.hbca.tech`, built
per the Phase 1 plan but never cut over. This incident affects the real,
currently-live unsuffixed containers, not an inert pair — including three
genuinely crash-looping production Celery workers (see Symptoms).

## Summary
The container that every HBEC service connects to by hostname (`hbec-redis`,
reached as `redis:6379`) has been running as a **read-only replica** since at
least 2026-09-25T12:04 — over 10 days — while Redis Sentinel has correctly
already promoted `redis-replica` to master. Nothing is actually broken at the
Redis/Sentinel layer: Sentinel did its job. The break is that
`REDIS_SENTINEL_HOSTS` is empty in production's `.env`, so every Django/FastAPI
service connects straight to the hardcoded `redis` hostname instead of asking
Sentinel which node is master — exactly the failure mode the compose file's
own comments warn about by name. Reads keep working (so every health check
stays green), and every write through that connection fails with
`redis.exceptions.ReadOnlyError: You can't write against a read only replica.`

## Symptoms
- `500 Internal Server Error` on endpoints that hit a cache *write* path —
  observed directly on `GET /api/internal/feedback/`, `GET
  /api/internal/students/`, `POST /api/internal/payments/webhook/`, `GET
  /api/internal/session-epoch/...` — all via DRF's rate-throttle class
  calling `cache.set()` on the throttle key.
- Intermittent, not constant: only 8 occurrences in `system_error_logs` across
  10 days, because most endpoints never exercise a cache-write path. This is
  exactly why it went unnoticed — the stack "looks" healthy.
- Reproduced live against the real production (unsuffixed) `student-backend`
  by calling `cache.set()` directly via Django shell — confirms this is not
  specific to any one environment or endpoint.
- **`hbec-student-worker`, `hbec-admin-worker`, `hbec-notifications-worker`
  (the real, singleton production Celery workers) were crash-looping**,
  `Restarting` every few seconds, 45-46 restarts logged by the time this was
  found. Root cause: both Celery's own `kombu.transport.redis.Mutex` (visibility
  restore on startup) and `redis.lock.Lock.acquire` call `SET NX` against
  Redis before the worker can come up — a write, so it crash-looped forever
  on the same `ReadOnlyError`. This meant **background job processing
  (replication stream consumption, offline sync, reminders, email) was fully
  down**, not just intermittent request 500s. `notifications-worker` crashed
  from the identical symptom despite the `notifications` service never even
  wiring `REDIS_SENTINEL_HOSTS` through — it doesn't need to; see Root Cause.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** every Django/FastAPI service that writes to the
  shared cache/broker over the `redis` hostname — confirmed on student-backend
  (blue and green); very likely admin-backend, harness, payments,
  notifications, Celery broker dispatch too, since they share the same
  misconfiguration pattern.
- **Related Components:** `hbec-redis` (app-facing hostname, now a replica),
  `hbec-redis-replica` (now the real master per Sentinel), `hbec-redis-sentinel`.
- **Time First Observed:** earliest matching `system_error_logs` row:
  2026-10-05 — but the underlying state (`hbec-redis` as replica) has existed
  since `hbec-redis`'s container start, 2026-09-25T12:00:35Z, essentially the
  same moment the earliest `ReadOnlyError` row was logged
  (2026-09-25T12:04:03Z).

## Investigation Steps

### 1. Initial Diagnosis
While testing a new MCP tool's `list_feedback` call against the live deployed
API (both `staging-admin.hbca.tech`→green and, for comparison,
`admin.hbca.tech`→blue/production), **every** call 500'd — including a
completely unfiltered `status=pending` call with none of today's new filter
code in the request path. That ruled out the new `has_errors`/`user_id`
filters as the cause before looking anywhere else.

### 2. Root Cause Analysis
```bash
# admin-backend-green logs showed the 500 was proxied straight through from
# student-backend-green's own /api/internal/feedback/:
docker logs hbec-admin-backend-green --since 5m | grep -A3 feedback

# Pulled the real traceback from student-backend-green:
docker logs hbec-student-backend-green --since 5m | grep -A40 'Internal Server Error: /api/internal/feedback'
# -> redis.exceptions.ReadOnlyError: You can't write against a read only
#    replica., raised from rest_framework.throttling.throttle_success ->
#    django.core.cache.backends.redis -> redis.client.execute_command

# Confirmed Redis's own view of itself:
docker exec hbec-redis redis-cli info replication          # role:slave, master_host:redis-replica
docker exec hbec-redis-replica redis-cli info replication  # role:master, connected_slaves:1

# Confirmed Sentinel's view - Sentinel already did the right thing:
docker exec hbec-redis-sentinel redis-cli -p 26379 sentinel masters
# -> name=hbec-redis, ip=redis-replica, port=6379, flags=master, role-reported=master

# Confirmed every app is bypassing Sentinel entirely:
grep -E '^(REDIS_SENTINEL_HOSTS|CELERY_BROKER_URL|REDIS_CACHE_URL)=' /opt/hbec/.env
# -> all three EMPTY

# Confirmed blue is equally affected, not just green (shared Redis):
docker exec hbec-student-backend-blue python manage.py shell -c \
  "from django.core.cache import cache; cache.set('healthcheck_test','1',5)"
# -> identical redis.exceptions.ReadOnlyError

# Confirmed onset via system_error_logs (production/blue's own log, shared
# across both colors since it's a singleton DB):
#   status_code=500, resolved=false, page_size=100 -> 77 total 500s,
#   8 of them ReadOnlyError, oldest 2026-09-25T12:04:03Z, newest
#   2026-10-05T17:47:06Z (today, reproduced live).
```

### 3. Key Findings
- Sentinel is not broken or mid-failover — `master_failover_state:no-failover`
  on both nodes, and Sentinel's own `sentinel masters` output is internally
  consistent and correct (`redis-replica` is master, `status=ok`).
- The compose file **already documents this exact failure mode** in a comment
  above the `redis-sentinel` service block (lines ~31-46 of
  `docker-compose.production.yml`): "while Sentinel is still running and still
  willing to promote the replica and demote that very node... every WRITE
  fails with READONLY... That is a real incident this stack has had more than
  once." The wiring to use Sentinel (`django-redis` SENTINELS,
  `CELERY_BROKER_URL = sentinel://...`, `Sentinel.master_for` in the harness)
  is already built and tested — only `REDIS_SENTINEL_HOSTS` in `.env` was
  never actually set in production.
- `hbec-redis` has been the replica since **2026-09-25**, not a recent event —
  this has been silently live for 10 days, caught only by accident while
  testing an unrelated feature today.

## Root Cause
Production's `.env` never set `REDIS_SENTINEL_HOSTS`, so every service
connects to Redis by a hardcoded hostname instead of asking Sentinel which
node is currently master. At some point (container recreate, restart, or an
earlier real failover) Sentinel correctly promoted `redis-replica` and
demoted `redis` — and because nothing was Sentinel-aware, every service kept
talking to the now-demoted `redis` hostname, which still answers reads (so
every health check and GET-only request looks fine) but refuses every write.

## Prevention / Rule
**Guardrail:** a deploy-time health check (part of
`scripts/deploy/verify-service-links.sh` or a new, small
`scripts/deploy/check_redis_writable.sh`) that performs one real
`SET`/`DEL` round-trip against the hostname each service actually uses for
cache/broker, and fails the deploy loudly if it gets `READONLY` — rather than
relying on Redis's own healthcheck, which only proves the node answers
`PING`/reads and would stay green through this exact failure.

This closes the gap directly: the Root Cause is that nothing in the deploy or
healthcheck path ever attempts a write, so a demoted-but-reachable Redis node
passes every existing check. A one-line write probe makes that undetectable
state loudly fail CI/deploy instead of surfacing 10 days later as scattered,
hard-to-correlate 500s.

## Solution

### Immediate Fix
**Applied 2026-10-05**, after confirming zero data divergence
(`hbec-redis`'s `slave_repl_offset` exactly matched `redis-replica`'s
`master_repl_offset` — `2530825588` on both — before touching anything):

```bash
# Sentinel already knew hbec-redis was a healthy, fully-synced replica
# (master-link-status:ok). Have Sentinel itself swap the roles back,
# rather than fighting its recorded state with a manual REPLICAOF:
docker exec hbec-redis-sentinel redis-cli -p 26379 sentinel failover hbec-redis

# Verified: redis -> role:master, redis-replica -> role:slave of redis,
# a real SET/GET round-trip against the `redis` hostname succeeded, and
# all 3 crash-looping workers came up healthy on their next restart with
# zero code or container changes (RestartCount stopped climbing at 45/45/46).
```

This is a genuine advantage of letting Sentinel drive the failover instead of
a manual `REPLICAOF NO ONE`: it fixed **every** affected service in one step,
including `payments`/`schools-backend`/`notifications`, none of which have
any Sentinel-awareness in their own code — they only needed the hardcoded
`redis` hostname to become writable again, which this restores without
touching their containers at all.

### Long-term Fix (not yet applied)
- Set `REDIS_SENTINEL_HOSTS=redis-sentinel:26379` in `/opt/hbec/.env` and
  recreate `student-backend`/`admin-backend`/`harness` (+ their workers/beats,
  + the inert `-blue`/`-green` pair) so those three service groups stop
  depending on which physical node currently holds the hardcoded hostname.
  Without this, the exact same incident recurs verbatim on the next real
  Sentinel failover — today's fix is a correct, safe recovery, not a
  prevention.
- **`payments`, `schools-backend`, and `notifications` have no Sentinel
  support in their own code at all** (confirmed: no `REDIS_SENTINEL_HOSTS`
  reference anywhere in `PAYMENTS/`, `SCHOOLS/`, `NOTIFICATIONS/`). They will
  be exposed to this exact failure again on the next real failover regardless
  of the `.env` change above — closing this gap needs a code change (port the
  same `django-redis` SentinelClient / `Sentinel.master_for` pattern already
  proven in student-backend/admin-backend/harness), not a config flip.
- Add the write-probe guardrail above to the deploy pipeline.
- Consider making `REDIS_SENTINEL_HOSTS` a `preflight-secrets.sh`-style
  mandatory-non-empty check in production specifically (it's fine for it to
  be empty in a single-node dev compose), so this can't silently regress back
  to off after being turned on.
- **Single point of failure in the Sentinel setup itself**: `sentinel
  sentinels hbec-redis` returned no other known sentinels
  (`num-other-sentinels: 0`, `quorum: 1`) — there is exactly one Sentinel
  process, so Sentinel's own availability is unmonitored and unredundant.
  A real outage of `hbec-redis-sentinel` itself would leave no automatic
  failover mechanism at all.

## Prevention
- [x] Immediate: Sentinel-orchestrated failover restored the `redis`
      hostname as writable master (2026-10-05)
- [ ] Configuration change: set `REDIS_SENTINEL_HOSTS` in `/opt/hbec/.env`,
      recreate the 3 Sentinel-aware service groups + their workers/beats +
      the inert blue/green pair
- [ ] Code change: add Sentinel support to `payments`/`schools-backend`/
      `notifications` — they have none today
- [ ] Monitoring/alert to add: Prometheus alert on `redis_role{host="redis"}`
      != expected, or on any `READONLY`/`ReadOnlyError` appearing in
      `system_error_logs`
- [ ] Add the write-probe guardrail to `verify-service-links.sh` or a new
      dedicated script, wired into `cd.yml`
- [ ] Add a second Sentinel instance for quorum redundancy
- [ ] Documentation: note in `docs/DEPLOYMENT.md` that
      `REDIS_SENTINEL_HOSTS` must be set in any environment with more than
      one Redis node, and correct any doc that still describes `-blue` as
      the live production environment (it is not — see Correction above)

## Related Issues
- Found while verifying the feedback-filter admin API changes shipped in
  commit `2804d78` (deploy-to-green round 4) — that work is unaffected; the
  500s this surfaced are this unrelated, pre-existing infra issue.

## References
- `docker-compose.production.yml` lines ~31-46 (the comment that already
  predicted this exact failure mode)
- `redis.exceptions.ReadOnlyError` traceback via
  `rest_framework.throttling.throttle_success`

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Crash loop and live crisis resolved same day as
discovery (10 days after onset). Durable Sentinel-aware fix for
student-backend/admin-backend/harness, and the code-level gap in
payments/schools-backend/notifications, remain open follow-ups.
