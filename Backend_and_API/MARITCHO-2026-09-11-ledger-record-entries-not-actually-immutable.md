# Ledger and Record Entries Had No DB-Level Immutability Enforcement

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
Maricho's core trust promise is that `ledger_entries` (deposit/balance/
release money movements) and `record_entries` (signed-off proof-of-work)
are immutable once written — this is a named design principle in the PRD
("A record entry is immutable") and `database_schema_design.md` explicitly
calls for "database-level triggers to RAISE EXCEPTION on UPDATE or DELETE."
That trigger was never built: both tables were plain mutable Postgres
tables, so any code path (or a future admin tool, or a bug) could silently
alter a financial ledger entry or an already-signed-off job record with no
DB-level guard at all.

## Symptoms
- No trigger, rule, or constraint in the schema preventing `UPDATE`/`DELETE`
  on `ledger_entries` or `record_entries`.
- The only protection was applicaton-level discipline (nothing in the
  FastAPI routes even exists yet to attempt an edit) — i.e. no protection.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** Postgres schema (`ledger_entries`, `record_entries`)
- **Related Components:** future ledger/dispute logic (Sprint 2, CORE-003/004)
- **Time First Observed:** 2026-09-11, backend schema audit

## Investigation Steps

### 1. Initial Diagnosis
Re-read `database_schema_design.md` §3 ("Immutability") against the actual
migration — the doc said triggers "will implement," past tense was never
reached in code.

### 2. Root Cause Analysis
`BACK-003` (initial migration) shipped the tables and an
`amount > 0` `CHECK` constraint, but the immutability trigger itself was
never written in any migration.

### 3. Key Findings
Verified experimentally against a local Postgres container: before the fix,
`UPDATE ledger_entries SET amount = 99.00 WHERE id = ...` succeeded with no
error.

## Root Cause
The design doc described the trigger as a future commitment; no backlog
item or migration ever tracked actually writing it, so it was silently
skipped.

## Prevention / Rule
**Guardrail:** For every hard invariant a design doc states as a guarantee
("immutable," "unique per X," etc.), require a passing CI integration test
that actively attempts the forbidden operation and asserts the database
itself rejects it — not a docstring or comment claiming the behavior
exists, a real `UPDATE`/`DELETE` attempt that must error.

That single test class would have caught this the day the doc was written
that "will implement" was never converted into an actual migration —
because until such a test exists and passes, "immutable" is a claim, not a
fact about the schema.

## Solution

### Long-term Fix
Added migration `989350a9dd8d_immutable_ledger_and_record_entries.py`
creating a shared `prevent_mutation()` PL/pgSQL function and attaching
`BEFORE UPDATE OR DELETE` triggers to both tables. Verified against a local
Postgres container that the trigger actually fires:

```sql
UPDATE ledger_entries SET amount = 99.00 WHERE id = '...';
-- ERROR:  ledger_entries is immutable: UPDATE not permitted on table ledger_entries
```

Also confirmed downgrade drops the triggers/function cleanly and re-upgrade
reapplies them.

## Prevention
- [x] Code changes made (migration with triggers, verified live)
- [x] Documentation updated (`database_schema_design.md` §3 now states the
  triggers are implemented, naming the migration)
- [ ] When ledger/dispute logic (CORE-003/CORE-004) is built, add an
  integration test asserting the DB raises on direct mutation attempts, per
  `engineering_standards.md`'s TDD requirement.

## Related Issues
- [[2026-09-11-crew-tables-missing-from-implementation]]

---

**Resolved By:** Claude Code (backend schema audit)
**Time to Resolution:** Same session
