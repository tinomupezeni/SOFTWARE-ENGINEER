# PRD §7.3: "500 concurrent buyers" exceeds Postgres' default max_connections

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
PRD §7.3 specifies a flash-sale scenario with 500 concurrent buyers against 10 seats, but
Postgres defaults to `max_connections = 100`. A direct reading — one connection per buyer —
fails immediately with `FATAL: sorry, too many clients already`. Compounding this, opening 500
connections costs ~7.0 s of a ~10.3 s workload, so roughly 70% of the run is connection setup
rather than the seat-claiming work the exercise teaches. "500 buyers" must mean 500 logical
workers multiplexed over a bounded pool, which changes both the performance budget and what the
scenario actually simulates.

## Symptoms
- The first benchmark run aborted with a connection error, not a timing result:
  ```
  psycopg.OperationalError: connection failed: connection to server at "172.24.0.2", port 5432 failed:
  FATAL:  sorry, too many clients already
  ```
- After raising `max_connections=600`, the 500-connection configuration measured
  `connect_ms: 7466` against `workload_ms: 2600` — setup dominated the run.
- The same 500 logical buyers over 50 connections took `connect_ms: 740` and finished in
  ~2.5 s total.

## Environment Details
- **Server/Host:** Local development host, Docker 29.8.0, shared container-backed storage.
- **Services Affected:** Runner sandbox Postgres 16; every scenario with high buyer counts.
- **Related Components:** `runner/bench/latency.py`, PRD §7.3, PRD §10 sandbox architecture.
- **Time First Observed:** 2026-09-27, during the first measured latency run.

## Investigation Steps

### 1. Initial Diagnosis
The benchmark failed at connection time rather than producing timings, so the ceiling was
suspected before any performance work.

### 2. Root Cause Analysis
```bash
# Postgres default ceiling
docker exec <pg> psql -U bench -d bench -tAc "SHOW max_connections"

# reproduce at the default, 500 concurrent connections
# -> FATAL: sorry, too many clients already
```
`SHOW max_connections` returned 100. The PRD never mentions raising it, so the 500-buyer
figure was only ever achievable by reading it as logical workers rather than connections.

### 3. Key Findings
- Default `max_connections` is 100; 500 connections requires explicitly setting 600+.
- Opening 500 connections costs ~7.0 s; opening 50 costs ~0.7 s. Connection setup, not the
  workload, dominated the 500-connection run.
- With 50 pooled connections the invariant held cleanly: `winners=100/100`,
  `over_allocation=0`, total ~2.5 s, both samples.

## Root Cause
The PRD specified a buyer count without specifying the connection topology behind it. Postgres'
default connection ceiling is lower than the PRD's buyer count, and connection establishment —
not the contended work — dominates when every buyer gets its own connection. The scenario
description and the resource model were never reconciled.

## Prevention / Rule
**Guardrail:** Every scenario spec must state its connection topology alongside its worker
count, and the runner must reject a scenario whose connection requirement exceeds
`max_connections` (or pool it) before the run starts.

A scenario that says "500 buyers" without saying how many connections carry them is
ambiguous in exactly the way this defect exploited: the reader assumes one-per-worker, the
runtime assumes a pool, and the gap only appears at run time as a connection error.

## Solution

### Immediate Fix
Benchmarked both topologies and adopted 500 logical buyers over 50 pooled connections as the
design, which fits inside the default `max_connections = 100` and lands the run at ~2.5 s.

```bash
# verify the ceiling before trusting a scenario
docker exec <pg> psql -U bench -d bench -tAc "SHOW max_connections"
```

### Long-term Fix
- Add connection topology to the scenario schema (workers, connections, pool size).
- Gate scenario validation on `required_connections <= max_connections`, failing fast at
  authoring time rather than at run time.
- Pool connections in the warm pool, not just databases — §7.3's budget and §10's warm pool
  both need updating to reflect that connection setup is a first-class cost.

## Prevention
- [x] Measured and documented the ceiling and both topologies
- [ ] Add `connections`/`pool_size` to the scenario schema
- [ ] Validate at authoring time instead of at run time
- [ ] Correct PRD §7.3's budget and §7.3's connection assumption
- [ ] Update PRD §10's warm pool to pool connections, not only databases

## Related Issues
- `Architecture_and_Design/ARCHCODE-2026-09-27-per-attempt-container-costs-92s.md` — the other
  component of the same critical path.

## References
- `reports/ARCHCODE-2026-09-27-run-latency-budget.md` — Finding 3
- `ARCHCODE-PRD.md` §7.3, §10
- `Club Zero/runner/bench/latency.py`, `results-*.json`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~1h (diagnosis, dual-topology measurement, write-up)
