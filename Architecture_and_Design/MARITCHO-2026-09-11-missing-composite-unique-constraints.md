# Missing Composite Unique Constraints on Skills and Service Areas

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`database_schema_design.md` specifies `UNIQUE(worker_id, trade)` on
`skills` and `UNIQUE(worker_id, suburb)` on `service_areas` ("A worker
cannot have duplicate entries for the same trade" / "cannot duplicate
suburb coverage"). Neither constraint existed in `backend/app/models.py`
or the initial migration — `models.py` even had a stale comment on `Skill`
flagging the missing constraint, but it was never acted on, and
`ServiceArea` had no such note at all despite the same gap.

## Symptoms
- A worker could insert the same `(worker_id, trade)` pair into `skills`
  multiple times, or the same `(worker_id, suburb)` pair into
  `service_areas` multiple times, with no DB-level rejection.
- Downstream effects: the matching engine (Sprint 2, CORE-002) filters by
  trade/suburb — duplicate rows would silently skew or duplicate match
  results.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `skills`, `service_areas` tables
- **Related Components:** future matching engine (CORE-002)
- **Time First Observed:** 2026-09-11, backend schema audit

## Investigation Steps

### 1. Initial Diagnosis
Cross-checked `database_schema_design.md` §2 "Composite Unique Constraints"
against `backend/app/models.py`; found the `Skill` class carried a
`# Needs UniqueConstraint('worker_id', 'trade') in args` comment that was
never implemented, and `ServiceArea` had the identical gap unremarked.

### 2. Root Cause Analysis
Same root cause pattern as the immutability trigger: documented in the
design doc, never carried through to the ORM model or migration.

## Root Cause
Implementation drift from an otherwise-correct design doc; the one comment
that did flag it was never resolved.

## Prevention / Rule
**Guardrail:** A pre-commit/CI grep that fails the build on any `# TODO`/`# Needs UniqueConstraint(...)`-style comment left unresolved in `models.py` — or, more directly, a CI check that parses `database_schema_design.md`'s composite-unique-constraint table and asserts a matching `UniqueConstraint` exists in `__table_args__` for each row.

The gap here wasn't a lack of documentation — the comment already named the missing constraint — it was that nothing made an unresolved TODO block a merge.

## Solution

### Long-term Fix
Added `UniqueConstraint('worker_id', 'trade', name='uq_skills_worker_trade')`
to `Skill.__table_args__` and
`UniqueConstraint('worker_id', 'suburb', name='uq_service_areas_worker_suburb')`
to `ServiceArea.__table_args__` in `backend/app/models.py`, and generated/
applied migration `a725b45e4046_add_crew_tables_and_composite_unique_.py`.
Verified live against a local Postgres container that a duplicate
`(worker_id, trade)` insert is now rejected:

```
ERROR:  duplicate key value violates unique constraint "uq_skills_worker_trade"
DETAIL:  Key (worker_id, trade)=(...) already exists.
```

## Prevention
- [x] Code changes made and verified against a live database
- [x] Stale TODO comment removed from `Skill` now that it's implemented

## Related Issues
- [[2026-09-11-crew-tables-missing-from-implementation]]

---

**Resolved By:** Claude Code (backend schema audit)
**Time to Resolution:** Same session
