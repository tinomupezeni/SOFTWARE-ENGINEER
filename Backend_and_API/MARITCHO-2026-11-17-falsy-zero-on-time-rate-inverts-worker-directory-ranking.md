# Falsy-zero `or` on `on_time_rate` ranks the worst-performing worker as flawless

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** Medium
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
In `ListNearbyWorkersUseCase.execute` (`backend/app/apps/workers/domain/services.py:547`), the
worker-directory ranking computes `ontime_rank = -(item.on_time_rate or _DEFAULT_ON_TIME_RATE)`.
`item.on_time_rate` is a real, reachable `Decimal("0.00")` for a worker who disputed every completed
job — and `Decimal("0.00")` is falsy in Python, so `or` silently substitutes
`_DEFAULT_ON_TIME_RATE = Decimal("100.00")` (the "perfect" default meant only for workers with no
completed jobs yet). The worst-performing worker in the directory is therefore ranked as if flawless,
ahead of genuinely good-but-imperfect workers, on the on-time-rate tiebreaker.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- A worker with `on_time_rate == Decimal("0.00")` sorts into the worker directory as though their
  on-time rate were 100%, outranking workers with real but imperfect rates (e.g. 85%) on this
  tiebreaker.

## Environment Details
- **Server/Host:** N/A (backend FastAPI service)
- **Services Affected:** Worker directory search/ranking (`GET /workers`)
- **Related Components:** `ListNearbyWorkersUseCase`, `WorkerDirectoryItem`
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding flagged the `or`-based default substitution on line 547 as a falsy-zero bug,
contrasting it with the repository layer's correct `is not None` pattern used for the same field
elsewhere.

### 2. Root Cause Analysis
- Exact line: `ontime_rank = -(item.on_time_rate or _DEFAULT_ON_TIME_RATE)`.
- `_DEFAULT_ON_TIME_RATE = Decimal("100.00")` (line 47).
- `item.on_time_rate` is a non-Optional `Decimal` on `WorkerDirectoryItem`, populated by
  `WorkerDirectoryRepository.list_workers` using the correct pattern
  `standing.on_time_rate if standing and standing.on_time_rate is not None else _DEFAULT_ON_TIME_RATE`
  — so by the time it reaches line 547 it is either the real computed rate or an already-defaulted
  100.00, never `None`.
- The real rate is computed via
  `_pct(stats.total_completed - stats.total_completed_and_disputed, stats.total_completed, _DEFAULT_ON_TIME_RATE)`,
  which only returns the default when the denominator is `<= 0`; with `total_completed > 0` and every
  completed job disputed, it legitimately returns `Decimal("0.00")` — a real worst-case value, not a
  sentinel for "unset."
- `services.py` lines 158-170 and `repositories.py` lines 376-378/390-394/485-487 all correctly use
  `... is not None else _DEFAULT_...` for on_time_rate/dispute_rate/fill_rate elsewhere — only this one
  ranking line regresses to the falsy-`or` pattern.

### 3. Key Findings
- The bug is isolated to the `ontime_rank` sort key; `dispute_rate`/`fill_rate` aren't used in this
  sort-key tuple, and `jobs_rank = -(item.jobs_completed or 0)` uses the same falsy-`or` pattern but is
  harmless there since 0 is the only falsy value an int can take and is also the intended default.

## Root Cause
The ranking code reused the "default on missing value" idiom (`value or default`) that is correct
when the field can be `None`/absent, but by the time this code runs `on_time_rate` is already a
fully-defaulted `Decimal` that can legitimately equal `0.00` — a real, meaningful value, not an
absence — so the truthy/falsy check silently overwrites a correct computed value.

## Prevention / Rule
**Guardrail:** A lint rule (custom ruff/semgrep pattern) flagging `x or <DEFAULT_CONSTANT>` wherever
`x` is statically known to be a non-Optional numeric field (as `WorkerDirectoryItem.on_time_rate` is
typed), since the `or`-default idiom is only safe for `Optional` fields where `None` is the only thing
being defaulted against.

This targets the Root Cause directly: the bug only exists because the field's type (`Decimal`, not
`Decimal | None`) already proves it can't be missing at this point, so `or` was never doing useful
work — a type-aware lint rule would catch exactly this mismatch between field nullability and the
idiom used against it.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed ranking-correctness bug found during review of
PR #12; it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Replace line 547 with `ontime_rank = -item.on_time_rate` (no `or` needed, since the value is already
  guaranteed non-None/defaulted upstream) or, if defensive coding against future nullability changes
  is desired, use `-(item.on_time_rate if item.on_time_rate is not None else _DEFAULT_ON_TIME_RATE)`.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none
- [ ] Documentation to update — none
- [x] Code changes required — fix line 547's falsy-`or` pattern (not yet implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that introduced this ranking
  logic.

## References
- `backend/app/apps/workers/domain/services.py:547` (`ListNearbyWorkersUseCase.execute`)
- `backend/app/apps/workers/domain/services.py:47` (`_DEFAULT_ON_TIME_RATE`)
- `backend/app/apps/workers/infrastructure/repositories.py:376-378` (correct `is not None` pattern)
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
