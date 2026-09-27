# Toxiproxy in the request path costs ~2.3 s, not the 5 ms it advertises

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
PRD §10 puts a "stub gateway" and Toxiproxy in the sandbox request path. Measured, routing the
50-connection, 500-buyer workload through Toxiproxy with a fixed +5 ms profile and `jitter=0`
cost 4.7–5.4 s versus 2.5–2.8 s direct — **+2.2–2.6 s, roughly 90% overhead**. The nominal
per-packet latency is real, but the naive reading of it as "5 ms of overhead" is off by two
orders of magnitude, because the figure is per direction per connection and is multiplied
across 50 connections and several round trips each. If the injector sits in the path for the
whole run, it alone blows the near-instant budget.

## Symptoms
- Direct workload: ~2.5–2.8 s total (`connect_ms` ~0.7 s, `workload_ms` ~2.0 s).
- Same workload via Toxiproxy: ~4.7–5.4 s total (`connect_ms` ~2.1 s, `workload_ms` ~3.2 s).
- Connection setup alone rose from ~0.7 s to ~2.1 s.
- Both configurations held the invariant (`winners=100/100`, `over_allocation=0`), confirming
  this is a latency cost, not a correctness change.

## Environment Details
- **Server/Host:** Local development host, Docker 29.8.0.
- **Services Affected:** Runner sandbox; any scenario that fault-injects network conditions.
- **Related Components:** `shopify/toxiproxy:latest`, the stub gateway, PRD §10.
- **Time First Observed:** 2026-09-27, first measured Toxiproxy comparison.

## Investigation Steps

### 1. Initial Diagnosis
Suspected the proxy would cost roughly its configured latency; measured instead of assuming.

### 2. Root Cause Analysis
```bash
# proxy the database path with a fixed, non-random profile (PRD 7.4 forbids jitter)
docker exec <toxi> /go/bin/toxiproxy-cli create bench_pg \
  --listen 0.0.0.0:8666 --upstream postgres:5432
docker exec <toxi> /go/bin/toxiproxy-cli toxic add bench_pg \
  -t latency -n fixed5 -a latency=5 -a jitter=0 --upstream
```
The arithmetic explains the result: 5 ms per direction per connection, aggregated over 50
connections and multiple round trips each, is thousands of milliseconds of queueing — not the
5 ms a single packet would suggest.

### 3. Key Findings
- +2.2–2.6 s aggregate overhead for a 5 ms nominal profile: ~90% worse than direct.
- Connection establishment is disproportionately affected (~0.7 s → ~2.1 s), because every
  connection pays the profile cost during its handshake.
- Invariants unchanged, so the proxy is a pure latency tax, not a semantic change.

## Root Cause
The PRD places fault injection in the general request path without distinguishing between the
traffic a scenario is *teaching* and the traffic that merely *carries the workload*. A profile
intended to demonstrate one slow external call ends up taxing every database round trip in the
run, including the 400 losing buyers who contribute nothing to the lesson.

## Prevention / Rule
**Guardrail:** Fault injection must be scoped to the specific egress a scenario teaches, never
applied to the whole request path; the scenario spec must name the target of each toxic, and
the runner must fail if a toxic is attached to a path not named by that scenario.

This closes the gap because the failure mode is invisible in configuration — a 5 ms profile
looks harmless everywhere it is written. Naming the taught path forces the cost to be
attributed to the specific mechanism being demonstrated, which is where the realism is
actually required.

## Solution

### Immediate Fix
Adopted the rule that Toxiproxy attaches only to the call a scenario teaches (e.g. the
external HTTP call that holds a lock), leaving the database workload path direct. This keeps
real blocking-connection semantics for the mechanism under study while protecting the fast path.

```bash
# scoped: proxy only the taught call, not the database path
```

### Long-term Fix
- Add a `fault_targets` list to the scenario schema; toxics may only attach to those targets.
- Document the aggregate cost so nobody re-adds a whole-path profile for convenience.
- Note in PRD §10 that the stub gateway serves double duty (fault injection and AI response
  replay) and that both must be scoped, not global.

## Prevention
- [x] Measured direct vs. proxied cost on identical workloads
- [ ] Add `fault_targets` to the scenario schema and enforce it
- [ ] Record the aggregate cost in PRD §10 next to the diagram
- [ ] Keep the database path unproxied in the reference implementation

## Related Issues
- `Architecture_and_Design/ARCHCODE-2026-09-27-prd-500-buyers-exceeds-postgres-max-connections.md`
  — the other half of the same latency budget.
- `ARCHCODE-pressure-test.md` §3 — the realism-vs-latency dilemma this resolves.

## References
- `reports/ARCHCODE-2026-09-27-run-latency-budget.md` — Finding 4
- `ARCHCODE-PRD.md` §7.4, §10
- `Club Zero/runner/bench/latency.py`, `results-*.json`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~1h (measurement, comparison, design rule)
