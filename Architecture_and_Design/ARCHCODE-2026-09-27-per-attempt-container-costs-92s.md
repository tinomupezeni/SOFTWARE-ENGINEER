# A fresh container per attempt costs ~92 s; the warm pool is the whole design

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
PRD §10 mentions a "warm pool" in passing while describing a per-attempt sandbox. Measured, a
fresh Postgres 16 container per attempt costs ~92.2 s to reach readiness, giving a ~101.3 s
critical path. Reusing a warm database and resetting it with `TRUNCATE` + reseed costs ~5 ms
and yields a ~2.5 s critical path — a 40x difference. The warm pool is therefore not an
optimization to be adopted opportunistically; it is the difference between a product with a
tight loop and one no learner would sit through, and any future argument for per-attempt
isolation on convenience grounds should be rejected on these numbers.

## Symptoms
- Fresh container to `pg_isready`: 92,169 ms and 92,310 ms across two samples (very stable).
- Full naive path (fresh container + 500-buyer workload): ~101.3 s.
- Warm pool + `TRUNCATE` + reseed: 5 ms reset, ~2.5 s total.
- Template clone (`CREATE DATABASE ... TEMPLATE`): ~60 ms reset, ~10.2 s total — a valid
  middle option, but 4x slower than reuse because it also pays the 500-connection cost.

## Environment Details
- **Server/Host:** Local development host, Docker 29.8.0, shared container-backed storage.
- **Services Affected:** Every run; the entire per-attempt lifecycle.
- **Related Components:** Postgres 16 sandbox, PRD §10 warm pool, near-instant latency
  requirement.
- **Time First Observed:** 2026-09-27, first measured latency run.

## Investigation Steps

### 1. Initial Diagnosis
Suspected `initdb` would dominate the critical path but expected single-digit seconds.

### 2. Root Cause Analysis
```bash
# fresh container to readiness, repeated
docker run -d --name bench-initdb-<id> -e POSTGRES_PASSWORD=bench postgres:16
# then poll until: "<socket>:5432 - accepting connections"
```
The ~92 s covers the whole path — container creation, the image entrypoint, `initdb`, and the
first server start — not `initdb` in isolation. That is precisely the cost a per-attempt design
pays, and it is an order of magnitude beyond the "near instant" requirement.

### 3. Key Findings
- Per-attempt fresh container: ~101.3 s end to end, versus ~2.5 s warm — a 40x gap.
- Template clone is a real middle option at ~10.2 s, dominated by the 500-connection cost
  rather than by the clone itself (~60 ms).
- `TRUNCATE` + reseed measures at or below the harness's ~130 ms round-trip floor, so reset is
  effectively free and reuse is the only sane design.

## Root Cause
The PRD specified sandbox isolation without quantifying the cost of that isolation, leaving
"warm pool" as an implementation detail rather than a load-bearing requirement. A 92 s
per-attempt cost is invisible in a design document and decisive in production.

## Prevention / Rule
**Guardrail:** The run latency budget must be an executable, checked assertion — the runner
must fail CI if a cold attempt exceeds the budget — and the warm pool must be a required
component of the sandbox spec, not an optional optimization.

This closes the gap because the failure is a *default*, not an error: nothing breaks, no test
fails, and the 92 s only shows up as a user complaint. Encoding the budget as an assertion
means the cost is discovered in CI rather than in front of a learner.

## Solution

### Immediate Fix
Adopted warm pool + `TRUNCATE` + reseed as the reference design (~2.5 s critical path), with
the pool itself treated as a required sandbox component.

```bash
# reset in one round trip
psql -tAc "TRUNCATE seats; INSERT INTO seats SELECT g, false FROM generate_series(1,100) g"
```

### Long-term Fix
- Fold the measured budget (and the harness's own floor) into PRD §7.3.
- Quantify the warm pool in §10 instead of mentioning it, with these numbers.
- Keep the benchmark in CI so pool regressions surface immediately.
- Investigate container pre-warm, which would make the budget conservative rather than tight.

## Prevention
- [x] Measured all three reset strategies across two samples
- [ ] Make the latency budget a CI assertion
- [ ] Update PRD §7.3 and §10 with measured numbers
- [ ] Keep `runner/bench/latency.py` in CI

## Related Issues
- `Architecture_and_Design/ARCHCODE-2026-09-27-prd-500-buyers-exceeds-postgres-max-connections.md`
- `Architecture_and_Design/ARCHCODE-2026-09-27-toxiproxy-request-path-costs-2s-not-5ms.md`

## References
- `reports/ARCHCODE-2026-09-27-run-latency-budget.md` — Finding 2
- `ARCHCODE-PRD.md` §7.3, §10
- `Club Zero/runner/bench/latency.py`, `results-*.json`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~1h (three-strategy measurement, two samples, write-up)
