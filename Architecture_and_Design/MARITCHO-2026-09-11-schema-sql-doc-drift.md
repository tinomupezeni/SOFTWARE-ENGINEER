# docs/architecture/schema.sql Drifted Significantly From the Real Alembic-Managed Schema

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
`docs/architecture/schema.sql` was written early as a design reference but
was never updated after the real schema was implemented via Alembic
(`backend/migrations/`). It was missing the entire `skills` table, several
columns actually present on `jobs`/`standings`/`record_entries`, used a
different column name (`type` vs. the real `entry_type`, `description` vs.
`problem_description`), and modeled enums as plain `VARCHAR` instead of the
real Postgres enum types. Anyone onboarding from this doc would build a
mental model of the schema that doesn't match the database Alembic
actually produces.

## Symptoms
- `docs/architecture/schema.sql` has no `CREATE TABLE skills`.
- `jobs` table in the doc lacks `next_of_kin_phone` (on persons),
  `problem_photo_url`, `quote_amount`, `updated_at`.
- `record_entries` in the doc lacks `before_photo_url`/`after_photo_url`/
  `signed_off_at`.
- `standings` in the doc lacks `jobs_completed`.
- Column name mismatches: `ledger_entries.type` (doc) vs. `entry_type`
  (real); `jobs.description` (doc) vs. `problem_description` (real).

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO`
- **Services Affected:** documentation only (`docs/architecture/schema.sql`)
- **Related Components:** `database_schema_design.md` (this one was
  accurate and used as the correction source)
- **Time First Observed:** 2026-09-11, backend schema audit

## Investigation Steps

### 1. Initial Diagnosis
Diffed `docs/architecture/schema.sql` against a `pg_dump --schema-only` of
the actual local dev database (post-Alembic-migration).

### 2. Root Cause Analysis
`schema.sql` predates several migration-driven additions
(`next_of_kin_phone`, photo/quote columns, `jobs_completed`, real enum
types) and was simply never regenerated or hand-updated afterward. Alembic
is the source of truth per `engineering_standards.md` §3 ("Never execute
manual SQL in production"), but nothing kept this reference file in sync
with it.

## Root Cause
No process ties `docs/architecture/schema.sql` to the Alembic migration
history, so it silently rotted as the real schema evolved.

## Solution

### Long-term Fix
Regenerated `docs/architecture/schema.sql` from a live `pg_dump` of the
Alembic-migrated dev database (including the new `crews`/`crew_members`
tables and immutability triggers from this same session), reformatted to
match the file's existing style, and added a header note explicitly
stating Alembic is canonical and this file is a reference snapshot only.

## Prevention
- [x] Doc regenerated to match reality
- [ ] Consider dropping this file entirely in favor of pointing engineers
  at `alembic history`/a generated ER diagram, since a manually-maintained
  duplicate of the schema will drift again without a process change.

## Related Issues
- [[2026-09-11-crew-tables-missing-from-implementation]]
- [[2026-09-11-ledger-record-entries-not-actually-immutable]]

---

**Resolved By:** Claude Code (backend schema audit)
**Time to Resolution:** Same session
