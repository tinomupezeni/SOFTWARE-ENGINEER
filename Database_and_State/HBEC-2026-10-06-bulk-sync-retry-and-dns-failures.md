# bulk.sync retries stuck at attempts=1; Sept 29 DNS failure cluster to harness

**Date:** 2026-10-06
**Project:** HBEC Platform
**Environment:** Production (VPS `gpu-ndime`)
**Severity:** Medium
**Status:** Investigating

## Summary
Of 9,141 `bulk.sync` replication rows, 435 are `failed` — every one with `attempts = 1` and `last_attempt_at` frozen at 2026-09-29 11:00. The error breakdown is 420 × `Temporary failure in name resolution`, plus a handful of connection-refused/reset, all targeting `harness`. Two open questions: whether the attempts-correlation fix (reuse rows on `(target, event_type, payload_hash)`, in `master`) actually covers the `bulk.sync` dispatch path, and what hostname failed to resolve that morning.

## Symptoms
- `SELECT status, count(*), max(attempts) ... WHERE event_type='bulk.sync'` → `failed | 435 | 1`, all from one 11:00 cluster on 2026-09-29.
- No `bulk.sync` failure since — so the retry path is currently unproven in production either way.
- 435 failed full-payload rows (~26 MB) retained alongside the successes.

## Environment Details
- **Server/Host:** gpu-ndime
- **Services Affected:** admin → harness bulk replication (content freshness for AI marking context)
- **Related Components:** `ReplicationService.dispatch()`, `bulk.sync` task, harness bulk endpoint, DNS/container networking
- **Time First Observed:** 2026-10-06 (failures themselves: 2026-09-29 11:00 UTC)

## Investigation Steps

### 1. Initial Diagnosis
Grouped `replication_logs` by `(event_type, status)`; the `attempts = 1` ceiling on every failed row matches the exact bug shape HBEC's CLAUDE.md documents as fixed (unconditional `create()` + `attempts += 1` writing a fresh `attempts: 1` row per retry). Verified the correlation fix IS present in `master` code (`services.py` reuses rows on `(target, event_type, payload_hash)`).

### 2. Root Cause Analysis
TBD: (a) whether `bulk.sync` flows through the fixed `dispatch()` or a separate path that still creates-per-attempt; (b) whether the Sept-29 rows predate the fix's deploy (prod runs `sha-e44223f`); (c) which hostname failed DNS (check `HARNESS_SERVICE_URL` history / container DNS at the time — likely fallout of a network/compose event, same morning as other infra churn).

### 3. Key Findings
- Failure signature is environmental (DNS + refused/reset), not payload: 96% name resolution.
- All failures target `harness` (1,100 failed rows total across types, all `target_service='harness'`).

## Root Cause
TBD — likely: environmental DNS outage on 2026-09-29 + retry counter never incrementing on the `bulk.sync` path (fix coverage gap) or rows predating the fix. Update after code-path check.

## Prevention / Rule
**Guardrail:** the retry-correlation invariant needs a test that fails when any dispatch path creates a fresh row instead of reusing `(target, event_type, payload_hash)` — one parametrized test over every `dispatch*` entry point, so a new bulk/one-off path cannot silently reintroduce per-attempt rows. (Mirrors the `admin-copy.test.ts` philosophy: the property that matters is asserted where it can drift.)

## Solution

### Immediate Fix
TBD — confirm path coverage; if `bulk.sync` bypasses `dispatch()`, route it through the correlated write; consider replaying the 435 (content now current via later syncs — verify before replaying stale payloads).

### Long-term Fix
- Parametrized retry-correlation test over all dispatch paths.
- Alert on `replication_logs` failure-rate spike (the Sept-29 cluster was silent for a week).

## Prevention
- [ ] Correlation test across dispatch paths
- [ ] Failure-rate alert on replication logs
- [ ] DNS/container-network postmortem for 2026-09-29 11:00 if still unexplained
- [ ] Code changes required (pending path-coverage verdict)

## Related Issues
- `Database_and_State/HBEC-2026-10-06-replication-log-unbounded-retention.md` (same table, retention facet)

## References
- `ADMIN/adminBackend/apps/replication/services.py:330-371` (correlation fix in `master`)
- Error sample: `[Errno -3] Temporary failure in name resolution` (420/435)

---

**Resolved By:** TBD
**Time to Resolution:** TBD
