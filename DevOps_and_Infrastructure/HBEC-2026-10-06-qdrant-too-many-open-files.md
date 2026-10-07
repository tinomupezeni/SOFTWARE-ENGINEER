# Qdrant rejecting connections — file descriptor exhaustion

**Date:** 2026-10-06 (found) / 2026-10-07 (root-caused and fixed)
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`, 209.209.42.142)
**Severity:** High (compounded into a platform-wide marking outage — see Update below)
**Status:** Resolved

## Summary
`hbec-qdrant` (v1.12.1) reports `Up (unhealthy)` and its log is a solid wall of `actix_server::accept: Error accepting connection: Too many open files (os error 24)`. The vector store cannot accept new connections, which degrades semantic marking, RAG retrieval, and the harness embedding pipeline that depend on it.

## Symptoms
- Container healthy-check failing; status `Up 12 days (unhealthy)`.
- Log tail is exclusively `Too many open files` on accept, repeated several times per second.
- No Qdrant data-loss signal observed (process alive, storage intact) — this is an FD-limit problem, not corruption.

## Environment Details
- **Server/Host:** gpu-ndime (VPS)
- **Services Affected:** hbec-qdrant; downstream: harness semantic marking / RAG / embeddings
- **Related Components:** qdrant storage volume, Docker `ulimits`, host `fs.file-nr`
- **Time First Observed:** 2026-10-06 ~07:55 UTC (during read-only VPS appreciation pass)

## Investigation Steps

### 1. Initial Diagnosis
`docker ps` flagged the single unhealthy infra container; `docker logs --tail` showed the accept loop failing on EMFILE/ENFILE continuously.

### 2. Root Cause Analysis
To be confirmed: process FD count (`/proc/<pid>/fd` or `lsof | wc -l`), container ulimit (`docker inspect` `Ulimits`), host `fs.file-nr` vs `fs.file-max`, and whether the growth is sockets (leaked connections from clients without pooling/timeouts) or storage segments. Qdrant 1.12 with default Docker `nofile` (1024:1024 inherited or compose-capped) exhausts fast under a leaky client or segment churn.

### 3. Key Findings
- Accept-side failure only: existing connections/storage unaffected so far.
- The failure is continuous, not a spike — the limit is Structurally too low or a leak never releases.

## Root Cause
TBD — FD exhaustion (limit too low and/or FD leak). Update on fix.

## Prevention / Rule
**Guardrail:** every stateful container in `docker-compose.production.yml` gets an explicit `ulimits: nofile` sized for its workload (Qdrant ≥ 65536), plus a Prometheus alert on `process_open_fds / process_max_fds > 0.8` (and host `node_filefd_allocated / file-max`) so the next approach warns days early instead of arriving as an unhealthy container.

## Solution

### Immediate Fix
TBD — likely: raise `nofile` ulimit (compose + host), restart Qdrant, verify collection integrity (`GET /collections`), watch FD count settle. If the count climbs straight back, hunt the leaking client (connection pooling / timeouts on the harness `qdrant-client`).

```bash
# Diagnose (read-only)
ssh hbca-vps "docker inspect hbec-qdrant --format '{{.HostConfig.Ulimits}} {{.State.Pid}}'"
ssh hbca-vps "cat /proc/\$(docker inspect hbec-qdrant --format '{{.State.Pid}}')/limits | grep -i 'open files'"
ssh hbca-vps "curl -sf localhost:7033/collections | head -c 500"
```

### Long-term Fix
- Explicit `ulimits` for qdrant/postgres/redis in production compose.
- FD-ratio alerting (container + host).
- Audit harness Qdrant client for pooling/timeouts if FDs regrow post-restart.

## Prevention
- [ ] `ulimits: nofile` on all stateful services in production compose
- [ ] Prometheus alert: FD usage ratio > 0.8 (container + host)
- [ ] Runbook entry: Qdrant EMFILE triage (limits → restart → integrity check → leak hunt)
- [ ] Code changes required (only if a client leak is confirmed)

## Related Issues
- `HBEC-2026-10-07-circuit-breaker-stuck-open-after-trip.md` — a critical,
  independently-discovered bug (a platform audit, not this investigation)
  that turned this single-container issue into a platform-wide one. Qdrant's
  own accept failures tripped the circuit breaker guarding every Qdrant
  collection; that breaker never recovered on its own, so one Qdrant
  hiccup left marking/search degraded indefinitely afterward, until either
  the harness process restarted or (this entry) the dependency itself got
  fixed. Both are now fixed; neither alone would have been enough — a
  perfectly working breaker still correctly opens against a genuinely
  failing Qdrant, and a healthy Qdrant doesn't un-stick an already-wedged
  breaker on an older running process.

## References
- VPS: `/opt/hbec` (`docker-compose.production.yml`); Qdrant REST on the stack's `7033`-mapped port

## Update 2026-10-07 — root cause confirmed, fixed

Ran the diagnosis this entry had queued but never completed:

```
docker inspect hbec-qdrant --format '{{json .HostConfig.Ulimits}}'
# null - no explicit ulimit at all

cat /proc/<pid>/limits | grep -i 'open files'
# Max open files    1024    524288   <- Docker's inherited default soft limit

cat /proc/sys/fs/file-nr   # host itself nowhere near its own file-max; not a host-level limit
```

**Root cause confirmed**: no ulimit override anywhere in
`docker-compose.production.yml` (or the dev compose file - same gap,
same fix needed to avoid yet another dev/prod drift this week), so Qdrant
ran on Docker's default **1024** open files. Six active collections
(`model_answers`, `curriculum_content`, `marking_knowledge`,
`learner_memory`, `semantic_cache`, `marking_schemes`), each with several
RocksDB segment files, plus client sockets from every harness worker across
both blue and green, comfortably exceeds that.

### Immediate Fix
Added explicit `ulimits: nofile: {soft: 65536, hard: 65536}` to qdrant's
service block in both compose files (a ulimit only takes effect at
container creation, so this needed a recreate, not a config reload):

```bash
cd /opt/hbec
source scripts/deploy/color-env.sh blue   # qdrant is a shared singleton, unaffected by which color is live
sudo -E docker compose -f docker-compose.production.yml up -d --no-deps --wait --wait-timeout 60 qdrant
```

Verified: new limit confirmed in `/proc/<pid>/limits` (65536/65536); all 6
collections recovered 100% on restart (confirmed via a live `GET
/collections` through `harness-blue`, not just the healthcheck); zero
`Too many open files` lines and zero new circuit-breaker trips in the
minutes immediately after, versus a continuous stream of both before.

### Long-term Fix
Done for Qdrant. Still open, out of scope for this entry: the same gap
exists for `postgres` and `redis` in the same compose file - no stateful
service in it has an explicit ulimit. A Prometheus alert on FD-usage ratio
(container `process_open_fds`/`process_max_fds` and host
`node_filefd_allocated`/`file-max`) is still not implemented - this issue
would otherwise have been caught by that alert, not by a user report.

## Prevention
- [x] `ulimits: nofile` on qdrant in both compose files
- [ ] Same for postgres and redis (same file, same gap, not done here)
- [ ] Prometheus alert: FD usage ratio > 0.8 (container + host)
- [x] Runbook entry: this file now serves as the Qdrant EMFILE triage
      reference (limits → recreate → integrity check → watch)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Found 2026-10-06; root-caused and fixed 2026-10-07
(~20 minutes from confirmed diagnosis to verified clean)
