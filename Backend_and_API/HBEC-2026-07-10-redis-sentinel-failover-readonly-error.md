# Redis Sentinel Failover — Celery Workers Crash with ReadOnlyError

**Date:** 2026-07-10
**Project:** HBEC Student Platform
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
On July 9, Redis Sentinel triggered a failover that promoted `hbec-redis-replica` to master after `hbec-redis` went down temporarily. When `hbec-redis` came back up, it rejoined as a slave. However, all services were hardcoded to connect to `redis://redis:6379/1` (the `hbec-redis` container hostname), which was now a read-only replica. Any write operation to Redis — Celery broker LPUSH, cache writes, mutex locks — failed with `ReadOnlyError`, causing the Celery workers to crash-loop and topic creation to return 500 errors.

## Symptoms
- Adding topics from the admin frontend returned `500 Internal Server Error`
- `kombu.exceptions.OperationalError: You can't write against a read only replica.` in admin-backend logs
- Celery workers (`admin-worker`, `student-worker`) in continuous restart loop
- `hbec-admin-worker` logging `Unrecoverable error: ReadOnlyError` on every startup
- Topic creation succeeded in PostgreSQL but failed when the post-save signal tried to publish to the Celery broker

## Environment Details
- **Server/Host:** VPS — 209.209.42.142 (hbec-vps)
- **Services Affected:** admin-backend, admin-worker, admin-beat, student-backend, student-worker, student-beat, harness, harness-embeddings
- **Related Components:** Redis (`hbec-redis`, `hbec-redis-replica`), Redis Sentinel (`hbec-redis-sentinel`), Celery workers, Django signal-based replication
- **Time First Observed:** 2026-07-10 ~09:49 UTC (worker crash-loop), root cause from 2026-07-09 11:38 UTC (failover)

## Investigation Steps

### 1. Initial Diagnosis
Checked container status — saw `admin-worker` and `student-worker` restarting repeatedly. Checked their logs — immediate `ReadOnlyError` on startup. Checked Redis roles — discovered the mislabeling.

```bash
# Checked container status
docker ps --format 'table {{.Names}}\t{{.Status}}'

# Checked Redis roles
docker exec hbec-redis redis-cli ROLE
# → slave

docker exec hbec-redis-replica redis-cli ROLE
# → master
```

### 2. Root Cause Analysis
Traced the sentinel logs to find when the failover occurred and reconstructed the timeline.

```bash
# Sentinel logs revealed the failover
docker logs hbec-redis-sentinel | grep -E 'failover|sdown|odown'
# → +sdown master hbec-redis redis 6379 (11:38:20)
# → +try-failover master hbec-redis redis 6379 (11:38:20)
# → +selected-slave slave 172.19.0.10:6379 (11:38:55)

# Confirmed sentinel knows the correct master
docker exec hbec-redis-sentinel redis-cli SENTINEL get-master-addr-by-name hbec-redis
# → 172.19.0.10 (hbec-redis-replica)
# → 6379

# Checked Django production settings for sentinel support
grep -n 'SENTINEL\|sentinel' STUDENT/hbec_backend/config/settings/production.py
# → Code already supports sentinel-based Redis, just not activated
```

### 3. Key Findings
- Sentinel itself worked correctly — it detected the failure, failed over, and knows the current master
- Redis containers are **mislabeled**: `hbec-redis` = slave, `hbec-redis-replica` = master
- All services hardcoded to `redis://redis:6379/1` which resolves to `hbec-redis` (the slave)
- Both Django backends (admin + student) and the harness already have sentinel-aware Redis configuration — it just needs `REDIS_SENTINEL_HOSTS` env var set
- Sentinel config was bind-mounted as a file, preventing it from persisting config changes (`Resource busy`)

## Root Cause
A Redis failover swapped master/slave roles on July 9. Services continued connecting to the same hostname (`redis` → `hbec-redis`) which was now a read-only replica. The sentinel-based discovery was already coded but never activated via `REDIS_SENTINEL_HOSTS`.

## Prevention / Rule
**Guardrail:** A startup health check that performs a real write-then-delete against the configured Redis connection (not just a `PING`) and refuses to mark the service ready if it fails.

That converts "silently connected to a stale read-only replica after a failover" into an immediate, visible startup failure, instead of a slow-building multi-service crash loop that was only noticed because someone happened to check container status.

## Solution

### Immediate Fix
Restarted the Redis containers via Docker Compose to restore original roles (hbec-redis as master, hbec-redis-replica as slave).

### Long-term Fix
Two changes made to prevent recurrence on future failovers:

1. **Activated Sentinel Discovery** — Set `REDIS_SENTINEL_HOSTS=redis-sentinel:26379` in `.env`. All services now dynamically discover the current Redis master via Sentinel instead of connecting to a hardcoded hostname.

2. **Fixed Sentinel Config Persistence** — Changed sentinel config mount from a file bind mount (`./docker/sentinel.conf:/sentinel.conf`) to a directory mount (`./docker/sentinel:/sentinel`) so sentinel can atomically write its config on state changes.

```bash
# Changes applied:
# 1. Created writable sentinel config directory
mkdir -p docker/sentinel && cp docker/sentinel.conf docker/sentinel/

# 2. Updated docker-compose.yml & docker-compose.production.yml
#    command: redis-sentinel /sentinel/sentinel.conf
#    volumes:  - ./docker/sentinel:/sentinel

# 3. Set env var
echo 'REDIS_SENTINEL_HOSTS=redis-sentinel:26379' >> .env

# 4. Restarted services
docker compose up -d redis-sentinel
docker compose up -d admin-backend admin-worker admin-beat \
  student-backend student-worker student-beat harness harness-embeddings
```

## Prevention
- [x] Configuration changes — `REDIS_SENTINEL_HOSTS` set in `.env`
- [x] Sentinel mount fixed to persist config
- [ ] Monitoring/alerts to add — alert when `ReadOnlyError` appears in any service logs
- [ ] Documentation to update — note in runbook about sentinel failover behavior
- [ ] Consider adding Redis hostname alias or VIP that tracks the master (e.g., HAProxy)

## Verification
After the fix, topic creation was tested end-to-end:
- `POST /api/curriculum/topics/` → 201 Created
- `topic_published` queued to StreamOutbox
- `replicate_topic_to_harness` task → harness responded HTTP 200
- Zero `ReadOnlyError` in any service logs

## Related Issues
- Sentinel "Resource busy" warning on config save (pre-existing, now fixed)

## References
- Django settings sentinel config: `ADMIN/adminBackend/config/settings/production.py:60-85`
- Student sentinel config: `STUDENT/hbec_backend/config/settings/production.py:92-127`
- Harness sentinel config: `AGENTIC_HARNESS/app/config.py:92-103`
- Signal handlers: `ADMIN/adminBackend/apps/replication/signals.py:236-264`

---

**Resolved By:** Tino
**Time to Resolution:** ~1 hour (diagnosis + fix + verification)
