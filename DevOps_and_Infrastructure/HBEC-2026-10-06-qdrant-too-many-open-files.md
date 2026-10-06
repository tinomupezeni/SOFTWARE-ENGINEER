# Qdrant rejecting connections — file descriptor exhaustion

**Date:** 2026-10-06
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`, 209.209.42.142)
**Severity:** High
**Status:** Investigating

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
- None yet (first Qdrant incident logged for HBEC)

## References
- VPS: `/opt/hbec` (`docker-compose.production.yml`); Qdrant REST on the stack's `7033`-mapped port

---

**Resolved By:** TBD
**Time to Resolution:** TBD
