# Notifications worker crash-looping on Redis read-only replica

**Date:** 2026-10-06
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`, 209.209.42.142)
**Severity:** High
**Status:** Investigating

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
TBD — expected: worker's Redis connection resolved to the replica after a Sentinel failover (or was started against it) and never re-resolved. Update on fix.

## Prevention / Rule
**Guardrail:** every Celery worker entrypoint must resolve the Redis master through Sentinel at startup (never a hardcoded node address) and crash on boot if the resolved node answers `READONLY` to a `SET` probe — fail-fast on boot rather than crash-looping on the first real write.

A client that re-resolves the master on `ReadOnlyError` (drop pool, re-discover, single retry) would close the remaining window without operator action.

## Solution

### Immediate Fix
TBD — likely `docker restart hbec-notifications-worker` to force Sentinel re-resolution, after confirming Sentinel's current master view. If it re-pins, inspect client config (`REDIS_SENTINEL_HOSTS` / `REDIS_URL`) next.

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

## Related Issues
- `DevOps_and_Infrastructure/HBEC-2026-07-13-redis-sentinel-500-error.md` (same Sentinel setup, client-config facet)
- HBEC CLAUDE.md "side effect must not fail..." / Sentinel failover notes

## References
- VPS: `/opt/hbec` (`docker-compose.production.yml`), live stack `hbec-*` + `bg-*`

---

**Resolved By:** TBD
**Time to Resolution:** TBD
