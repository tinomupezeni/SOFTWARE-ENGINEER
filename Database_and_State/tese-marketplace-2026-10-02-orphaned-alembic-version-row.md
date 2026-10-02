# Production DB had an orphaned alembic_version row with no matching migration anywhere

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Production
**Severity:** Low
**Status:** Resolved

## Summary
While adopting real Alembic migrations for the first time (replacing this
repo's ad-hoc raw-SQL `migrations/*.py` script pattern), the first
`alembic revision --autogenerate` run failed immediately with `Can't
locate revision identified by '002_add_listing_type'`. The production DB
already had an `alembic_version` table containing that revision id, but
no migration file with that id - or any Alembic setup at all - existed
anywhere in the repo's git history. A prior, apparently abandoned attempt
at adopting Alembic had gotten as far as running one migration against
production, then had its migration files lost or never committed.

## Symptoms
- `alembic revision --autogenerate -m 'baseline'` (run inside
  `tese-store-api` via `docker exec`) failed with:
  ```
  ERROR [alembic.util.messaging] Can't locate revision identified by '002_add_listing_type'
  FAILED: Can't locate revision identified by '002_add_listing_type'
  ```

## Environment Details
- **Server/Host:** Production (`tese-db-legacy` container, `tese_store`
  database)
- **Services Affected:** None functionally - `alembic_version` is
  Alembic's own bookkeeping table, not application data; nothing reads
  it except Alembic itself
- **Related Components:** `apps/store-api/alembic/`
- **Time First Observed:** 2026-10-02, during initial Alembic adoption

## Investigation Steps

### 1. Initial Diagnosis
Queried the table directly rather than guessing:
```sql
SELECT * FROM alembic_version;
-- version_num: 002_add_listing_type
```
Confirmed via `find`/`git log` that no `alembic/versions/` directory or
any file matching that revision id has ever existed in this repo's
history - this wasn't something removed, it was never committed in the
first place.

### 2. Root Cause Analysis
The revision id's name (`002_add_listing_type`) closely echoes this same
session's earlier `Category.listing_type` column work
(`Backend_and_API/tese-marketplace-2026-09-28-category-listing-type-silently-dropped.md`),
but that work was done via a plain SQL `ALTER TABLE` script
(`migrations/add_category_listing_type.py`), not Alembic - so this is
very likely evidence of a separate, earlier attempt (by whoever worked on
this codebase before) to start using Alembic for that same change, which
got as far as running `alembic upgrade` once against production but never
had its migration files committed to version control.

### 3. Key Findings
- This is purely a bookkeeping artifact - the actual `categories` table
  schema was already correct and in sync with the models (confirmed by
  the baseline autogenerate producing an empty `pass`/`pass` migration
  once this was cleared), so there was no data or schema risk, only
  Alembic's internal state being inconsistent with reality.
- A raw `DROP TABLE alembic_version` was attempted first and correctly
  blocked by this environment's destructive-action safeguards; resolved
  instead with Alembic's own `stamp --purge` command, which clears the
  version table through the tool's normal, supported mechanism rather
  than a manual DDL drop.

## Root Cause
A previous, incomplete attempt to adopt Alembic ran one migration against
production without ever committing the corresponding migration file(s) to
the repository, leaving the database's bookkeeping table pointing at a
revision nothing in version control can resolve.

## Prevention / Rule
**Guardrail:** Never run `alembic upgrade`/`alembic revision` against a
real environment before the generated migration file is committed and
pushed - the migration file and the database's version pointer must
never be allowed to exist independently of each other, even briefly. If
generating interactively, commit immediately after confirming the file
looks correct, before moving on to anything else.

## Solution

### Immediate Fix
```bash
docker exec tese-store-api alembic stamp --purge base
# clears the version table via Alembic's own mechanism, not a raw DROP

docker exec tese-store-api mkdir -p alembic/versions
docker exec tese-store-api alembic revision --autogenerate -m 'baseline'
# generated an empty (pass/pass) migration - models and DB already matched

docker exec tese-store-api alembic stamp head
# marks it applied without running any DDL, since schema already matched
```
Copied the generated migration file back into the repo and committed it
(see the companion report) so the baseline persists across future
rebuilds instead of only existing in the running container's writable
layer.

### Long-term Fix
None needed - this was a one-time cleanup required to adopt Alembic at
all; the guardrail above prevents recurrence going forward.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `reports/tese-marketplace-2026-10-02-foundations-alembic-and-dead-code-cleanup.md`
  (the initiative this was found and fixed under)
- `Backend_and_API/tese-marketplace-2026-09-28-category-listing-type-silently-dropped.md`
  (the likely-related earlier work whose Alembic attempt left this stray
  row)

## References
- `apps/store-api/alembic/`
- `apps/store-api/alembic/versions/e87a2c1df002_baseline.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~10 minutes from first failure to cleared state
