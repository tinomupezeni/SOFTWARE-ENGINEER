# Redis Is Provisioned as a "Message Broker" in the System Design but Only Ever Pinged for Health Checks — No Background Job Processing Exists

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Medium
**Status:** Resolved (as a documentation/scoping fix — see Solution)

## Summary
`docs/architecture/system_design.md` §1 names Redis as the "Message
Broker" for "background job queues (Celery/ARQ), handling image processing
and offline-sync ingestion," and the component diagram shows a distinct
`Worker` process consuming from it. None of that exists. The only code
that ever touches Redis is `app/redis.py::get_redis_client` and its single
call site: the `redis_client.ping()` inside `/health/ready`. There is no
Celery/ARQ integration, no task queue, no worker process, and — as a
direct consequence — every operation the docs describe as
"should be async" (image processing, notification routing, offline-sync
ingestion, and by extension any future standing recomputation) runs
synchronously in the request/response cycle, tying API latency directly to
that work's cost.

## Symptoms
- `grep -rn "redis_client\|get_redis_client" app/` finds exactly one real
  usage: the readiness probe's `await redis_client.ping()`.
- `grep -rn "celery\|arq" app/ backend/pyproject.toml` — confirmed empty in
  the earlier dev-tooling audit this same day; still true.
- Every "heavy" operation in the app (matching computation, standing
  recomputation if it existed, ledger writes) executes inline inside a
  FastAPI request handler with no queueing.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/redis.py`, the entire request-handling path
  (nothing is ever offloaded)
- **Related Components:** `backend/docker-compose.yml` (redis service
  exists and is health-checked, but serves no functional purpose today)
- **Time First Observed:** 2026-09-11, architecture review requested
  directly by the user ("what's the backend architecture... is it
  scalable")

## Investigation Steps

### 1. Initial Diagnosis
Asked what the actual role of Redis is in the running system versus what
the architecture doc claims.

### 2. Root Cause Analysis
```bash
grep -rn "redis_client\|get_redis_client" app/ --include="*.py"
```
Confirmed the only call site is the health probe. No queue library is a
dependency, no worker entrypoint/Dockerfile/compose service exists for a
worker process, and `system_design.md`'s component diagram (`Redis -->
Worker --> DB`) has no corresponding code anywhere in the repo.

### 3. Key Findings
- This is consistent with, and partly explains, the separate finding that
  `Standing` reputation is never recomputed — there is nowhere for that
  kind of derived/background computation to run even if someone wrote it,
  since the worker-process half of the architecture was never built.
- Every current backend feature (Quick Hire, Crew Hire, disputes) happens
  to be fast enough sync-in-request that this gap hasn't caused visible
  problems yet — but photo compression, notification fan-out, and any
  future batch recomputation all assume a worker tier that isn't there.

## Root Cause
`ADR-001` decided on "Redis + Celery (or ARQ)" for background jobs, and
`system_design.md` describes it as already part of the topology, but no
backlog item in `docs/backlog.md` (Sprint 1–3) ever actually scoped
building it — Sprint 3 (`APP-00x`) is about the offline-first *client*, not
a backend worker tier, so the gap fell through a scoping seam between
sprints.

## Solution

### Immediate Fix
Put the scoping question to the user directly: build a worker tier now,
build a minimal one, or defer and correct the docs. Answer: **defer and
correct the docs** — standing recomputation (the one candidate workload
that existed) already runs synchronously and fast (see the Standing
finding), so there is currently no real async workload to justify
building Celery/ARQ ahead of one. Building it speculatively would be
unrequested infrastructure with no task to run on it yet.

Applied as a documentation/scoping correction, same day:
- `docs/architecture/system_design.md` §1: the "Message Broker" bullet no
  longer states Redis handles background jobs as fact — it now says
  explicitly that this is planned but not built, that Redis's only live
  usage is the `/health/ready` ping, and why (no workload needs it yet).
- The §2 component diagram's `Redis`/`Worker` edges are now dashed with a
  caption marking them aspirational, instead of implying they're live.
- `docs/architecture/adr/001-core-tech-stack.md` decision #5 now has an
  "Implementation status" sub-note recording the deferral and the
  condition for revisiting it (a genuinely heavy async task gets scoped —
  photo upload/compression, WhatsApp webhook processing, etc.).
- `docs/backlog.md` gets a real, trackable item: **BACK-007**, status
  `DEFERRED`, explicit trigger condition for picking it back up.

### Long-term Fix
Done, for now, as a deferral: no worker tier is being built until
`BACK-007`'s trigger condition (a real heavy async task is scoped) is
met. At that point the ADR's original decision (Redis + Celery/ARQ)
still stands and should be implemented then, not revisited from scratch.

## Prevention
- [x] Correct `system_design.md` (§1 and §2) to reflect current reality
  instead of describing infrastructure that doesn't exist
- [x] Add a backlog item (`BACK-007`) recording the deferral and its
  trigger condition, so this doesn't silently fall through a sprint-
  scoping seam again

## Related Issues
- Directly related to the Standing-never-recomputed finding (no worker
  tier to run recomputation on) and the earlier-logged audit finding that
  Crew Hire and background jobs were both named in the docs as unbuilt
  gaps

## References
- `docs/architecture/system_design.md` §1, §2 (component diagram)
- `docs/architecture/adr/001-core-tech-stack.md` — "Background Jobs: Redis
  + Celery (or ARQ)"

---

**Resolved By:** Claude Code (architecture-review-to-fixes session), scoping
decision confirmed by the user
**Time to Resolution:** Same day, follow-up session
