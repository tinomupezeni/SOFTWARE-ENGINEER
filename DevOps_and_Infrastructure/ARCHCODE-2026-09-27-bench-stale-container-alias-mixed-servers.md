# Benchmark silently mixed two Postgres servers via a stale network alias

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
A container left behind by a crashed benchmark run was still attached to the Docker network
while holding the `postgres` network alias. Docker DNS round-robins between aliased containers,
so roughly half of every new run's connections landed on the stale server, which lacked the
tables the run expected. This surfaced as sporadic `UndefinedTable` errors from 100 of 500
buyers — an error that names a missing table rather than a contaminated environment, so the
natural reading is "a bug in the workload." It was a bug in the harness. Unfixed, this would
have produced plausible-looking latency numbers averaged across two different databases, which
is worse than no measurement at all.

## Symptoms
- The seat table verifiably existed before and after runs, yet ~247 of 500 connections reported
  it invisible:
  ```json
  {"total": 500, "connected": 500, "distinct_db": ["bench"], "distinct_schema": ["public"],
   "bad_count": 247, "bad_sample": [{"i": 2, "db": "bench", "schema": "public",
                                     "seats_visible": 0, "ok": true}]}
  ```
- A diagnostic connection error listed **two** addresses for the same hostname:
  ```
  host: 'postgres', port: '5432', hostaddr: '172.24.0.4': ... too many clients already
  host: 'postgres', port: '5432', hostaddr: '172.24.0.2': ... too many clients already
  ```
  Two IPs for one alias is the actual tell; it was initially dismissed as retry noise.
- Buyers intermittently failed with `UndefinedTable`, and the pooled run aborted on its final
  invariant query.
- `docker ps` revealed `bench-pg-c031b7cd up 20 minutes` from an earlier crashed run.

## Environment Details
- **Server/Host:** Local development host, Docker 29.8.0.
- **Services Affected:** `runner/bench/latency.py` only — no production impact.
- **Related Components:** Docker network aliases, DNS round-robin, the benchmark harness.
- **Time First Observed:** 2026-09-27, mid-benchmark; misdiagnosed twice before the cause was found.

## Investigation Steps

### 1. Initial Diagnosis
Initially read `UndefinedTable` as a seeding bug and fixed the seed ordering — a real bug, but
not this one. Then read it as a connection-ceiling problem, which the "too many clients" error
appeared to confirm.

### 2. Root Cause Analysis
```bash
# the smoking gun: a stale container still holding the alias
docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -i bench
#   bench-pg-c031b7cd   Up 20 minutes

# confirm the alias is contested
docker network inspect archcode-bench \
  --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'
#   bench-pg-c031b7cd 172.24.0.2/16
#   bench-toxi-b2b15a1a 172.24.0.3/16
```
A crashed run's teardown did not complete, leaving a live server registered under the
`postgres` alias. The new run created a second container under the same alias, and DNS
distributed connections between them.

### 3. Key Findings
- ~50% of connections silently reached a different database, with the same name, schema, and
  credentials — so nothing about the connection itself revealed the problem.
- `distinct_db` and `distinct_schema` were both correct, which is why the diagnostic initially
  looked like it exonerated the environment.
- Teardown had not run for at least one prior run, leaving persistent contamination.

## Root Cause
The harness assumed exclusive ownership of a shared, fixed network name and a shared alias,
and registered no assertion that the alias resolved to exactly one endpoint. A crash therefore
left the environment permanently ambiguous, and the resulting measurements would have averaged
across two different databases while looking internally consistent.

## Prevention / Rule
**Guardrail:** The harness must pre-flight (remove stale `bench-*` containers and the network)
**and** assert after startup that the `postgres` alias resolves to exactly one container IP,
aborting the run otherwise.

The failure mode is invisible in the output — a wrong-environment measurement looks exactly
like a right one, and averages cleanly. Asserting on endpoint uniqueness converts a silent
correctness problem into a loud startup failure, which is the only property that protects the
numbers' meaning.

## Solution

### Immediate Fix
Added `preflight()` to remove leftover containers and networks, and
`_assert_single_postgres()` to fail the run if the alias does not resolve to exactly one IP.
Both run before any measurement.

```bash
# manual cleanup
docker rm -f $(docker ps -aq --filter "name=bench-")
docker network rm archcode-bench
```

### Long-term Fix
- Use a per-run unique network name so concurrent or crashed runs cannot collide.
- Verify expected state (row counts) from a fresh connection before measuring, as the
  benchmark now does for the seat table.
- Consider pinning images by digest to reduce the wider reproducibility risk this run exposed
  (see the related `toxiproxy:latest` tag-drift entry).

## Prevention
- [x] Pre-flight cleanup of stale containers and networks
- [x] Assert the `postgres` alias resolves to exactly one endpoint
- [x] Verify expected row counts before measuring
- [ ] Move to per-run unique network names
- [ ] Pin images by digest

## Related Issues
- `DevOps_and_Infrastructure/ARCHCODE-2026-09-27-toxiproxy-latest-tag-cli-drift.md` — the same
  benchmark, a different reproducibility hazard.

## References
- `reports/ARCHCODE-2026-09-27-run-latency-budget.md` — Changes Made / Verification
- `Club Zero/runner/bench/latency.py` — `preflight()`, `_assert_single_postgres()`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~45m (two misdiagnoses before isolating the two-IP signature)
