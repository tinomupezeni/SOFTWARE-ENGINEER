# Matching Engines Run One "Is This Busy" Query Per Candidate Instead of Batching — N+1 Pattern

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Both matching engines call a per-row "is this busy" check inside a Python
loop over candidates rather than batching the check into the main query.
`app/crew_matching.py::find_top_crew_candidates` calls
`is_worker_busy(db, worker_id)` once per skilled worker, and
`is_crew_busy(db, crew.id)` once per crew — each a separate round-trip
query. At today's pilot scale (a handful of crews/workers) this is
invisible; as the worker/crew base grows this becomes O(N) queries per
matching request instead of O(1).

## Symptoms
- `app/crew_matching.py:84`: `if not areas or await is_worker_busy(db, worker_id): continue` —
  inside `for worker_id in skilled_worker_ids:`.
- `app/crew_matching.py:99`: `if await is_crew_busy(db, crew.id): continue` —
  inside `for crew in crews:`.
- `app/matching.py::find_top_candidates` (individual job matching) avoids
  this specific pattern by folding the busy-check into the main query as a
  correlated `EXISTS` subquery — so the fix pattern already exists
  elsewhere in the same codebase, it just wasn't reused for the crew
  matching engine.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/crew_matching.py`
- **Related Components:** `app/matching.py::is_worker_busy` (the function
  being called in the loop), `GET /crew-orders/{id}/matches`
- **Time First Observed:** 2026-09-11, scalability review requested
  directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Compared the two matching engines side by side — `app/matching.py` folds
its busy-check into one query via a correlated subquery; `app/crew_matching.py`
does not.

### 2. Root Cause Analysis
`app/crew_matching.py` was written to reuse the *function*
`is_worker_busy` for consistency with the individual-job matching engine,
but that function's signature (`db, worker_id) -> bool`) is
inherently per-row, so reusing it as-is inside a loop reproduces the N+1
shape even though the sibling engine avoids it via a different query
structure (`~busy_subquery` folded directly into the main `SELECT`).

### 3. Key Findings
- Same root issue affects `is_crew_busy`, called once per crew in the
  outer loop of `find_top_crew_candidates`.
- Both could be replaced with a single batched query (e.g., one query
  returning the set of busy worker_ids/crew_ids up front, checked via an
  in-memory set inside the loop) without changing behavior.

## Root Cause
Reusing a per-row helper function inside a loop, instead of expressing
"which of these candidates are busy" as one set-based query — an easy
trap when a working per-row helper already exists and looks reusable.

## Solution

### Immediate Fix
Implemented in a follow-up session (same day):
- `app/matching.py::get_busy_worker_ids(db, worker_ids)` — one query
  (`SELECT DISTINCT worker_id FROM jobs WHERE worker_id IN (...) AND
  status IN JOB_BUSY_STATUSES`) returning the busy subset of a worker pool
  up front. (`_BUSY_STATUSES` was also renamed to the public
  `JOB_BUSY_STATUSES` so it could be reused across modules cleanly.)
- `app/crew_matching.py::get_busy_crew_ids(db, crew_ids)` — same pattern
  for crews via `crew_orders.crew_id`.
- `find_top_crew_candidates` now calls each once, before its loops, and
  the loops do an in-memory `worker_id in busy_worker_ids` /
  `crew.id in busy_crew_ids` check instead of `await`-ing a query per
  candidate. Went from O(N) queries per matching request to O(1) (two
  queries total, regardless of pool size).
- The original per-row helpers (`is_worker_busy`, `is_crew_busy`) are kept
  unchanged — they're still the right shape for their other call sites
  (single-worker booking check in `routers/jobs.py`, single-crew booking
  check in `routers/crew_orders.py`), which only ever check one candidate,
  not a pool.
- mypy caught a real edge case while typing the batched query: both
  `Job.worker_id` and `CrewOrder.crew_id` are nullable columns (a job with
  no worker assigned yet, a crew order not yet matched to a crew), so the
  raw query result is `Sequence[UUID | None]` even though a `None` can
  never actually appear in this result set (the `status.in_(...)` filter
  guarantees FK is set). Filtered it out explicitly in the set
  comprehension rather than asserting/ignoring, so the return type is a
  clean `set[uuid.UUID]`.

Verified: `ruff check .` and `mypy .` clean across all 40 source files;
full suite green (90 passed, 92.75% coverage, above the 85% gate) — no
behavior change to crew-matching results, only query shape.

### Long-term Fix
Done for both matching engines. The shared "batch busy-check" helper
pattern now exists in both `app/matching.py` and `app/crew_matching.py`;
no further extraction needed since there are only these two matching
engines.

## Prevention
- [x] Batch both busy-checks in `app/crew_matching.py`
- [x] A shared batching pattern (`get_busy_worker_ids`/`get_busy_crew_ids`)
  now exists for any future matching-engine variant to reuse instead of
  reintroducing a per-row loop

## Related Issues
- Compounded by the missing index on `jobs.worker_id` and
  `crew_orders.crew_id` (each of these per-candidate queries is also an
  unindexed scan) — see the separate missing-indexes finding

---

**Resolved By:** Claude Code (architecture-review-to-fixes session)
**Time to Resolution:** Same day, follow-up session
