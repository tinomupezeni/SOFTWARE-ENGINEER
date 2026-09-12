# No List Endpoint Has Pagination — Every List Response Returns Its Full Result Set

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
Every endpoint that returns a list (`GET /workers/me/skills`, `GET
/workers/me/service-areas`, `GET /suburbs`, `GET /jobs/{id}/ledger`, `GET
/jobs/{id}/disputes`, `GET /crew-orders/{id}/ledger`) returns its complete
result set with no `limit`/`offset` (or cursor) parameters anywhere. At
today's scale (a handful of rows per worker/job) this is unnoticeable; none
of these are unbounded-growth lists yet, but the pattern is consistent
across every list endpoint in the API, so it will need to be retrofitted
everywhere at once rather than being an isolated fix.

## Symptoms
- `grep -rn "limit\|offset\|Query(" app/routers/*.py` returns nothing —
  no endpoint accepts pagination parameters.
- Every list-returning route does `select(Model).where(...)` with no
  `.limit()`/`.offset()`, and every response model is a bare `list[...]`.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/routers/workers.py`, `app/routers/suburbs.py`,
  `app/routers/jobs.py`, `app/routers/crew_orders.py`
- **Time First Observed:** 2026-09-11, scalability review requested
  directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Scanned every router for list-returning endpoints and checked each for
pagination support.

### 2. Root Cause Analysis
None of these endpoints were ever expected to return large lists at the
scope they were built for (a worker's own skills, a job's own ledger
entries) — each is naturally small *per owning entity* today. The risk is
`GET /suburbs` (a shared reference table, currently 6 rows but grows with
coverage) and any future "list all my jobs" / "list all my crew orders"
endpoint, neither of which exists yet but would need pagination from day
one if added without noticing this gap.

### 3. Key Findings
- This is a systemic pattern, not a single-endpoint bug — worth fixing
  once, consistently (e.g., a shared pagination dependency/response
  wrapper), rather than endpoint-by-endpoint.

## Root Cause
No endpoint has yet hit a scale where this mattered, so pagination was
never added — a reasonable trade-off so far, but worth flagging explicitly
since it wasn't a deliberate decision, just an absence.

## Prevention / Rule
**Guardrail:** A repo-level test that inspects every router function whose
response model is a `list[...]` and asserts it declares the shared
pagination dependency — failing CI the moment a new list-returning endpoint
ships without it.

This turns "pagination was never a deliberate decision, just an absence"
into something that can't happen silently again: a new list endpoint
either declares pagination or fails the check, so the gap can't
re-accumulate unnoticed the way it did across all 6 original endpoints.

## Solution

### Immediate Fix
Implemented in a follow-up session (same day):
- New shared module `app/pagination.py`: a `Pagination` dataclass plus a
  `pagination_params` FastAPI dependency (`limit: Query(50, ge=1, le=200)`,
  `offset: Query(0, ge=0)`), so every list endpoint gets the same shape
  and cap from one place instead of reinventing it per-route.
- Wired into all 6 genuine list-returning endpoints: `GET /suburbs`,
  `GET /workers/me/skills`, `GET /workers/me/service-areas`,
  `GET /jobs/{id}/disputes`, `GET /jobs/{id}/ledger`,
  `GET /crew-orders/{id}/ledger`. Each query now chains `.limit()` /
  `.offset()`, and the two endpoints that had no `ORDER BY` at all
  (`skills`, `service-areas`) got one added (`ORDER BY id`) — pagination
  is meaningless without deterministic ordering, and this was a real gap
  the fix surfaced.
- Deliberately *not* applied to `GET /jobs/{id}/matches` or
  `GET /crew-orders/{id}/matches` — those are already hard-capped to the
  top 3 ranked candidates by the matching engines themselves
  (`MAX_CANDIDATES`/`MAX_CREW_CANDIDATES`), so pagination doesn't apply.
- `ruff`'s `flake8-bugbear` `extend-immutable-calls` got `fastapi.Query`
  added alongside the existing `fastapi.Depends`/`RequireRole` entries, to
  avoid a B008 false positive on `Query(...)` as a dependency default (the
  same class of fix already applied for `Depends` earlier this project).
- `docs/architecture/openapi.yaml` gets a reusable `components.parameters.limit`/`offset`
  pair, `$ref`'d from all 6 endpoints, instead of six duplicated definitions.
- Added `tests/test_suburbs.py::test_list_suburbs_respects_limit_and_offset`
  and `::test_list_suburbs_rejects_limit_above_the_cap`, verifying actual
  paged results (not just that the code runs) and the `422` at the cap.

Verified: `ruff check .` / `mypy .` clean (41 files); full suite green —
92 passed (up from 90; the 2 new tests), 92.82% coverage.

### Long-term Fix
Done — a standard pagination shape now exists (`app/pagination.py`) for
every current list endpoint and any future one to reuse without
reinventing the limit/offset/cap pattern.

## Prevention
- [x] Adopted a standard pagination shape (`app/pagination.py`) for all
  list endpoints
- [x] Retrofitted all 6 existing list endpoints now, rather than waiting
  for a real-growth incident to force it — this was cheap to fix
  consistently in one pass

## Related Issues
- None directly, but part of the same scalability review that found
  missing indexes and the N+1 matching-engine pattern

---

**Resolved By:** Claude Code (architecture-review-to-fixes session)
**Time to Resolution:** Same day, follow-up session
