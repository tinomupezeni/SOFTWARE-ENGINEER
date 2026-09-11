# Crew and CrewMember Tables Missing From Implementation Despite Being a Core Design Object

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
`Crew` is documented as one of "The Seven Core Objects" in
`docs/architecture/system_design.md` and is fully specified (with
`CREWS`/`CREW_MEMBERS` tables, FKs, and a 1:1 lead constraint) in
`docs/architecture/database_schema_design.md`'s ER diagram. Neither table
existed in `backend/app/models.py` nor in any Alembic migration — the
domain model had silently dropped one of its seven core entities.

## Symptoms
- No `Crew` or `CrewMember` class in `backend/app/models.py`.
- No `crews` / `crew_members` tables in the only existing migration
  (`7165c54ce358_initial_schema.py`).
- Sprint 2 backlog items (matching engine) and the Stage Two business-case
  milestone ("Crew Hire console for organizations") have no schema to build
  against.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app.models`, Alembic migrations
- **Related Components:** future Crew Hire endpoints (Sprint 2+)
- **Time First Observed:** 2026-09-11, backend schema audit before starting
  Sprint 2 (CORE-001)

## Investigation Steps

### 1. Initial Diagnosis
Compared the SDD's "Seven Core Objects" list and the schema design doc's ER
diagram against `backend/app/models.py` and the migration history.

### 2. Root Cause Analysis
The initial migration (`BACK-003`, marked `DONE` in `docs/backlog.md`) only
ever covered `persons`, `jobs`, `service_areas`, `skills`, `standings`,
`ledger_entries`, and `record_entries`. Crew support was designed but never
translated into the ORM layer or a migration — an implementation gap, not a
design one.

### 3. Key Findings
- `database_schema_design.md` already had the correct shape: `crews.lead_id`
  unique (1 crew per lead), `crew_members` as a composite-PK join table
  cascading on delete from both `crews` and `persons`.

## Root Cause
Design work outpaced implementation for this one entity; nothing enforced
that all seven documented core objects actually exist in code.

## Solution

### Long-term Fix
Added `Crew` and `CrewMember` to `backend/app/models.py` matching the
documented ER shape, and generated Alembic migration
`a725b45e4046_add_crew_tables_and_composite_unique_.py`. Verified against a
local Postgres container: migration applies cleanly, downgrades cleanly,
and `alembic check` reports no drift against the models afterward.

```bash
docker compose up -d
alembic upgrade head
alembic revision --autogenerate -m "add crew tables and composite unique constraints"
alembic upgrade head
alembic check   # No new upgrade operations detected.
```

## Prevention
- [x] Code changes made (models + migration)
- [ ] Consider a CI check that diffs the SDD's core-object list against
  `app.models` module contents, so a documented entity can't silently go
  unimplemented again.

## Related Issues
- [[2026-09-11-missing-composite-unique-constraints]]
- [[2026-09-11-schema-sql-doc-drift]]

---

**Resolved By:** Claude Code (backend schema audit)
**Time to Resolution:** Same session
