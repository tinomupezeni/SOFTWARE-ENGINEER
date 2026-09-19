# Job/Crew Order Creation Echoed Raw Input Instead of DB-Normalized NUMERIC Precision

**Date:** 2026-09-18
**Project:** MARITCHO
**Environment:** Development (caught by test suite during a backend restructuring, never reached production)
**Severity:** Medium
**Status:** Resolved

## Summary
While restructuring the FastAPI backend from a flat modular monolith into Clean Architecture with domain-based apps, the ported `SqlAlchemyJobRepository.create()` and `SqlAlchemyCrewOrderRepository.create()` methods dropped a `db.refresh()` call that the original monolithic router handlers had performed after commit. Two tests (`test_buyer_can_create_job_request_with_geo_fields`, `test_crew_order_request_accepts_optional_geo_fields`) failed: submitting `latitude: "-20.2050"` returned `"-20.2050"` in the response instead of the expected `"-20.205000"`.

## Symptoms
- `POST /jobs/request` and `POST /crew-orders/request` with `latitude`/`longitude` echoed the raw input string's decimal places instead of the value Postgres actually stored.
- Only surfaced because the two geo-field tests explicitly asserted on the padded 6-decimal form; any code relying on the returned value having full `NUMERIC(9,6)` precision downstream would have silently received fewer decimal digits than what was actually persisted.

## Environment Details
- **Server/Host:** local dev / CI test run (Dockerized Postgres 15)
- **Services Affected:** `backend-api` (jobs and crew-orders creation endpoints)
- **Related Components:** `app/apps/jobs/infrastructure/repositories.py::SqlAlchemyJobRepository.create()`, `app/apps/crews/infrastructure/repositories.py::SqlAlchemyCrewOrderRepository.create()`
- **Time First Observed:** 2026-09-18, first full test run after porting the `jobs` and `crews` apps to the new architecture

## Investigation Steps

### 1. Initial Diagnosis
Ran the full pytest suite after completing the restructuring; two failures, both asserting on `latitude`/`longitude` formatting, both off by the same shape (fewer trailing zeros than expected).

### 2. Root Cause Analysis
Compared the new repository's `create()` method against the original router handler (`app/routers/jobs.py`, pre-restructuring), which called `await db.refresh(job)` immediately after `await db.commit()`. The new `create()` method only did `self._db.add(model)` + `await self._db.flush()`, then converted the in-memory model straight to a domain entity — never re-reading it from Postgres.

### 3. Key Findings
- `NUMERIC(9,6)` columns are stored by Postgres at their declared scale (`-20.205000`), but a SQLAlchemy ORM attribute holds whatever Python value was assigned to it until the object is explicitly refreshed from a row — `flush()` alone pushes the write but does not pull the DB-side representation back.
- The original code's `db.refresh()` after commit was doing real, load-bearing work (normalizing precision for the API response), not just a defensive habit — it was easy to drop while porting logic into a new repository method because nothing about the method signature signaled that requirement.

## Root Cause
The repository `create()` methods flushed the new row (to populate the DB-generated UUID `id`) but never refreshed the ORM object afterward, so the returned domain entity carried the client-supplied `Decimal` verbatim instead of the value Postgres actually normalized and stored.

## Prevention / Rule
**Guardrail:** Any repository `create()`/`add()` method that maps user input directly onto a `Numeric`/`Decimal` column must call `await db.refresh(model)` after `flush()`, not just flush — add this as a required step in the repository-implementation checklist (alongside the existing "wrap unique-constraint inserts in try/except IntegrityError" rule) referenced from `docs/architecture/adr/007-clean-architecture-with-domain-apps.md`.

This closes the gap because it makes the DB round-trip explicit at the exact point a value could silently diverge from what's stored, rather than relying on someone remembering that a specific column type needs it.

## Solution

### Immediate Fix
Added `await self._db.refresh(model)` immediately after `await self._db.flush()` in both `SqlAlchemyJobRepository.create()` and `SqlAlchemyCrewOrderRepository.create()`.

```python
self._db.add(model)
await self._db.flush()
await self._db.refresh(model)
return _job_to_entity(model)
```

### Long-term Fix
Covered by the guardrail above; no further code change needed since both known call sites (jobs, crew orders) are fixed and no other `create()`/`add()` method in the new architecture maps raw input onto a `Numeric` column without an existing refresh or a subsequent read-back.

## Prevention
- [x] Code changes required (done — see Immediate Fix)
- [ ] Documentation to update (add the checklist item referenced above to ADR-007 or a repository-pattern note if this recurs)
- [ ] Monitoring/alerts to add (n/a — caught entirely by existing test assertions)
- [ ] Configuration changes needed (n/a)

## Related Issues
- Found during the same session as `MARITCHO-2026-09-18-coverage-blind-spot-across-sqlalchemy-async-greenlet-boundary.md` (Backend_and_API) — both surfaced while verifying the Clean Architecture restructuring.

## References
- `docs/architecture/adr/007-clean-architecture-with-domain-apps.md`

---

**Resolved By:** Claude Code (backend restructuring session)
**Time to Resolution:** ~10 minutes (caught immediately by existing test assertions on the first full suite run after the restructuring)
