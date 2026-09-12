# Worker "Standing" (Reputation) Is Never Recomputed After Initial Creation — The Whole Trust System Is Inert

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Critical
**Status:** Resolved

## Summary
The PRD and SDD both describe `Standing` (`grade`, `on_time_rate`,
`dispute_rate`, `fill_rate`, `jobs_completed`) as "computed, never assigned"
— the core reputation mechanism the whole matching engine ranks candidates
by, and the thing the vision doc's success metrics (fill rate, dispute
rate) are built on. A full-codebase search confirms these fields are never
written anywhere except once, at row creation, with static defaults
(`grade="REGISTERED"`, rates at their initial values, `jobs_completed=0`).
No code path in the job lifecycle, crew-order lifecycle, or dispute
resolution flow ever updates a `Standing` row afterward. A worker who
completes 50 jobs flawlessly and a worker who has never worked show
identical standing forever.

## Symptoms
- `grep`-ing the entire `app/` tree for assignments to `on_time_rate`,
  `dispute_rate`, `fill_rate`, or `jobs_completed` finds only: their use as
  read-only inputs inside `app/matching.py`'s scoring function, their
  pass-through in `GET /workers/me/standing`, and their one-time defaulted
  creation in `app/routers/workers.py::_ensure_standing`.
- `complete_job` (`app/routers/jobs.py`) sets `Job.status = COMPLETED`,
  writes a `RecordEntry` and a `RELEASED` ledger entry — but never touches
  the completed job's worker's `Standing` row (doesn't increment
  `jobs_completed`, doesn't move `on_time_rate`/`fill_rate`).
- `respond_to_dispute` resolves the dispute and un-freezes the worker (via
  the computed `is_worker_disputed` check going back to `false`) — but
  never increments `Standing.dispute_rate`, so a worker who has been
  disputed 10 times looks identical, by this field, to one who never has.
- `book_crew_order` accepts a `deposit_amount` from the buyer with no
  relationship to `workers_needed` or any per-worker rate, and crew orders
  have no completed-jobs/fill-rate tracking for member workers at all.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/models.py` (`Standing`), `app/matching.py`,
  `app/routers/jobs.py`, `app/routers/crew_orders.py`,
  `app/routers/workers.py`
- **Related Components:** the entire matching-ranking mechanism in
  `find_top_candidates`/`find_top_crew_candidates` depends on these fields
  actually reflecting worker performance
- **Time First Observed:** 2026-09-11, architecture/scalability/
  normalization review requested directly by the user

## Investigation Steps

### 1. Initial Diagnosis
While answering "is the DB properly normalized," noticed `Standing`'s
"computed" fields have no obvious writer anywhere in the routers built
across the CORE-00x/CREW-00x work.

### 2. Root Cause Analysis
```bash
grep -rn "on_time_rate\s*=\|dispute_rate\s*=\|fill_rate\s*=\|jobs_completed\s*=" app/ --include="*.py"
grep -rn "Standing(" app/
```
Confirmed exactly one `Standing(...)` construction site
(`_ensure_standing`, called only when a worker registers their first skill
or service area), and zero UPDATE-shaped assignments to any of the four
"computed" columns anywhere else in the codebase.

### 3. Key Findings
- This was never scoped as a task in `docs/backlog.md` — CORE-003
  (ledger/booking) and CORE-004 (disputes) both shipped and were verified
  end-to-end without anyone noticing standing itself was never wired up,
  because nothing in the test suite asserts on post-completion standing
  values (tests only check the *default* `is_frozen`/`jobs_completed`
  behavior, never a post-completion recompute, because there is none to
  test).
- The matching engine's ranking (`_standing_score`) is fully implemented
  and does real work sorting candidates by grade/rates — it's just always
  sorting against static, never-changing input data.

## Root Cause
No backlog item ever specified *when* or *how* standing recalculation
should happen (on job completion? nightly batch? a rolling window?), so it
was never built — the matching/ranking machinery was built assuming the
data source would eventually be populated by something, and that something
was never written.

## Prevention / Rule
**Guardrail:** Any backlog item introducing a "computed" field that another
system depends on (a ranking score, a reputation value, an aggregate) must
name its recompute trigger explicitly in its acceptance criteria — on which
event, via which code path — before it can be marked DONE, and its test
suite must assert the value actually changes after that triggering event,
not just that it has a correct default at creation.

CORE-003/CORE-004 both shipped and were verified end-to-end without this
gap surfacing precisely because no test ever asserted on post-completion
standing values — only ever on the default. A recompute-trigger
requirement in the acceptance criteria closes exactly that blind spot.

## Solution

### Immediate Fix
Implemented in a follow-up session (same day): `app/standing.py::recompute_standing(db, worker_id)` fully
re-derives `jobs_completed`/`fill_rate`/`dispute_rate`/`on_time_rate` from
`Job`/`Dispute` history each time it's called (not incremented — so it can
never drift), using a concrete, documented formula:
- `jobs_completed` = count of this worker's `COMPLETED` jobs
- `fill_rate` = completed / total booked
- `dispute_rate` = (jobs with at least one dispute ever raised) / total booked
- `on_time_rate` = (completed jobs never disputed) / completed jobs

Wired into `complete_job` and `raise_dispute` (`app/routers/jobs.py`), so
standing updates the moment a dispute is raised (not just at completion)
and again on completion. `grade` is deliberately left untouched — no
documented threshold rule exists for grade progression (tracked
separately). Crew-order completions still don't feed into individual
worker standing — the crew-booking model has no per-member participation
record to attribute it to (documented as a known limit in the function's
docstring, not solved here).

### Long-term Fix
Still open: whether recomputation should move to a background job instead
of running synchronously in the request (moot until the Redis/background-
worker gap is addressed — see that finding), and whether/how crew-order
completions should eventually roll up into member standings.

## Prevention
- [x] `app/standing.py` added, wired into both call sites, verified with
  4 new tests (`tests/test_standing.py`) covering: single clean
  completion, a dispute alone, a disputed-then-completed job, and
  multi-job averaging across the same worker — all passing, `ruff`/`mypy`
  clean project-wide (39 files), full suite green (90 tests, 92.68% coverage)
- [ ] Decide on background-job recomputation once that infra exists
- [ ] Decide how/whether crew-order completions roll into individual standing

## Related Issues
- Tied to the DB normalization/scalability review that also found: missing
  FK indexes, the N+1 matching-engine query pattern, and Redis/background
  jobs never being implemented despite being named in `system_design.md`.

## References
- `docs/discovery/vision_document.md` — success metrics built on fill
  rate/dispute rate
- `docs/requirements/prd.md` §2 — "Standing... Computed, never assigned"
- `docs/architecture/system_design.md` — Standing as one of the "Seven
  Core Objects"

---

**Resolved By:** Claude Code (architecture-review-to-fixes session)
**Time to Resolution:** Same day, follow-up session
