# Staging's Local Ollama Fallback and Harness Container Were Both Under-Provisioned Relative to Production

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
Two staging-only resource ceilings (the local CPU Ollama fallback container,
and the harness container itself) were sized far below what the same
services run at in production, with no functional reason for the
difference — plain configuration drift. Both caused real crashes once admin
bulk generation started exercising the GPU path under real load.

## Symptoms
- litellm's fallback to the local CPU model failed with
  `"error":"llama-server process has terminated: signal: killed"`.
- Separately, the harness container itself got OOM-killed mid-request the
  moment a second concurrent admin generation overlapped with one already
  in flight, surfacing to the Django caller as a raw
  `httpx.RemoteProtocolError: "Server disconnected without sending a response"`
  instead of a clean error.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** `ollama` (local CPU fallback), `harness` (uvicorn, 8 workers)
- **Related Components:** `docker-compose.staging.yml`
- **Time First Observed:** 2026-09-09, during admin bulk-generation load testing

## Investigation Steps

### 1. Initial Diagnosis
`docker inspect` on both containers showed `OOMKilled: true`.

### 2. Root Cause Analysis
Compared staging's resource limits against production's for the same two
services:

```bash
docker inspect hbec-ollama-staging --format '{{.HostConfig.Memory}}'   # 512MB
docker inspect hbec-harness-staging --format '{{.HostConfig.Memory}}'  # 1536MB, 8 uvicorn workers
```
vs. `docker-compose.production.yml`'s definitions for the same two services:
`ollama` at 6G/4cpu, `harness` at 5G/6cpu — for the identical
`UVICORN_WORKERS=8` in both environments.

### 3. Key Findings
- 512M is nowhere near enough for `llama3.2:3b`'s ~2GB of Q4 weights — this
  fallback container was guaranteed to crash every time it was actually
  used, not an intermittent issue.
- 1.5G for 8 uvicorn workers of this app was already running at ~96% memory
  at steady state (`docker stats`) even before any large concurrent
  request — a single larger admin batch was enough to tip it into OOM.
- Both gaps were staging-only; production never had this problem because
  production was already sized correctly.

## Root Cause
Staging's `docker-compose.staging.yml` resource limits for `ollama` and
`harness` were never updated to match production's sizing for the same
`UVICORN_WORKERS`/model — plain environment drift, not a deliberate
"staging is lighter" choice.

## Prevention / Rule
**Guardrail:** A scheduled (or pre-promotion) script that diffs every
shared service's resource limits (`mem_limit`, `cpus`) between
`docker-compose.staging.yml` and `docker-compose.production.yml`, and
alerts on any gap that isn't explicitly documented as intentional.

This targets the root cause directly: the drift here wasn't a deliberate
"staging is lighter" decision, it was an update to production that never
got mirrored to staging — a diff check catches exactly that class of
silent divergence before it OOM-kills a container under real load.

## Solution

### Immediate Fix
None separate from the long-term fix — both were configuration values.

### Long-term Fix
- `ollama` (staging): raised from 512M/0.5cpu to 6G/4cpu, matching production.
- `harness` (staging): raised from 1.5G/1cpu to 3G/2cpu — not matching
  production's full 5G/6cpu 1:1 since staging doesn't carry production
  traffic, but enough that 8 workers of this app have real headroom instead
  of running at 96% at idle.

## Prevention
- [ ] Add a periodic staging-vs-production resource-limit diff check so this
      class of drift is caught before it causes an outage under load
- [x] Documented the "why" inline in `docker-compose.staging.yml` next to
      both changed limits, so a future edit doesn't silently reintroduce the gap

## Related Issues
- Companion: litellm router timeout killing GPU calls
- Companion: admin token budget / truncation issues (surfaced once these
  two OOM issues stopped masking them)

## References
- `docker-compose.staging.yml`
- Commit `ffa37566`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session
