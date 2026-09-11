# Almost Every Foreign-Key Column Lacks an Index — Every "Is This Busy" / Ledger-Sum Query Is a Sequential Scan

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
PostgreSQL does not automatically index foreign-key columns (only the
referenced side — the primary key — gets one). Across the entire schema,
`index=True` is never set on any column in `app/models.py`, and most FK
columns aren't the leading column of any unique constraint either. This
means the queries the app runs most often — "is this worker/crew already
busy," "sum this job's ledger entries by type," "list this job's disputes"
— all do a full sequential scan of their table today, and get linearly
slower as each table grows. At current pilot scale (a handful of rows) this
is invisible; it will not stay invisible.

## Symptoms
- `grep -n "index=True" app/models.py` returns nothing.
- Concretely unindexed columns that are queried directly and frequently:
  - `jobs.worker_id` — filtered on every single matching run via
    `is_worker_busy`/`is_worker_disputed` (`app/matching.py`)
  - `jobs.buyer_id` — no covering index
  - `ledger_entries.job_id` — filtered on every `/quote` and `/complete`
    call via `sum_ledger_entries` (`app/ledger.py`)
  - `crew_orders.crew_id` — filtered on every crew-matching run via
    `is_crew_busy` (`app/crew_matching.py`)
  - `crew_order_ledger_entries.crew_order_id` — filtered on every crew
    order `/quote` and `/complete` call
  - `disputes.job_id` and `disputes.raised_by_id` — filtered by
    `list_job_disputes`/`respond_to_dispute`
  - `record_entries.worker_id`, `crew_members.worker_id` (as the
    *second* column of its composite PK, so lookups by worker_id alone
    don't benefit from it) — no dedicated coverage
- Some FK columns get *partial* accidental coverage as the leading column
  of an existing unique/composite-PK index (`skills.worker_id`,
  `service_areas.worker_id`, `crew_members.crew_id`) — but this is
  incidental, not deliberate, and several equally hot columns get nothing.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/models.py`, every table with a FK
- **Related Components:** `app/matching.py`, `app/crew_matching.py`,
  `app/ledger.py` — all of the app's "busy check" and "sum ledger" query
  patterns
- **Time First Observed:** 2026-09-11, scalability review requested
  directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Asked "is this scalable" — checked whether the columns the matching/ledger
code filters on have any index backing them.

### 2. Root Cause Analysis
```bash
grep -n "index=True" app/models.py   # empty
```
Cross-referenced every `mapped_column(..., ForeignKey(...))` declaration
against `select(...).where(SomeModel.some_fk == ...)` call sites in
`app/matching.py`, `app/crew_matching.py`, `app/ledger.py`, and the
routers. Confirmed the columns listed above are both (a) genuinely
unindexed and (b) the actual WHERE-clause target of a query that runs on
common request paths (every match, every quote submission, every
completion).

### 3. Key Findings
- This isn't a one-off oversight on a single table — it's systemic: no
  migration in the whole history (`7165c54ce358` through `447e4d827227`)
  ever added an index beyond what a `UniqueConstraint`/`primary_key`
  incidentally provides.
- The matching engine in particular (`is_worker_busy`, `is_crew_busy`)
  calls these unindexed lookups inside per-candidate loops (see the
  separate N+1 finding), compounding the cost: an O(N) loop of O(table
  size) scans.

## Root Cause
Indexing was never treated as part of "the schema" the way FKs and
constraints were — every migration session added new tables/columns
correctly (types, nullability, FKs, `CheckConstraint`s) but nobody added
`index=True` to any FK, and nothing in the review process (`alembic
check`, the test suite) would ever catch a missing index, since both only
verify *correctness*, not query-plan efficiency.

## Solution

### Immediate Fix
Implemented in a follow-up session (same day): added `index=True` to all
11 previously-uncovered FK columns in `app/models.py` —
`persons.guarantor_id`, `crew_members.worker_id`, `crew_orders.buyer_id`,
`crew_orders.crew_id`, `crew_order_ledger_entries.crew_order_id`,
`jobs.buyer_id`, `jobs.worker_id`, `ledger_entries.job_id`,
`disputes.job_id`, `disputes.raised_by_id`, `record_entries.worker_id`.
Generated migration `4fa80902185b_add_indexes_on_foreign_key_columns.py`
via `alembic revision --autogenerate` (confirmed all 11 indexes were
picked up automatically, nothing missed).

Verified rather than assumed:
- Applied the migration, then ran `alembic check` — "No new upgrade
  operations detected."
- Ran a full round-trip (`alembic downgrade -1` → `alembic upgrade head` →
  `alembic check`) to confirm both directions are correct, not just
  upgrade.
- Confirmed the indexes physically exist in the running container:
  `docker compose exec db psql -U postgres -d maricho -c "\di ix_*"`
  lists all 11.
- Ran `EXPLAIN` on the exact hot-path query `is_worker_busy` issues
  (`SELECT id FROM jobs WHERE worker_id = :id AND status IN (...)`) and
  confirmed the planner now uses `Index Scan using ix_jobs_worker_id`
  instead of a sequential scan.
- Full test suite: 90 passed, 92.68% coverage (above the 85% gate);
  `ruff check .` and `mypy .` both clean project-wide.

### Long-term Fix
Done — no further columns identified as needing coverage beyond the 11
above. Remaining open item: no automated check yet enforces that a new FK
column added in a future migration also gets an index in the same
migration (see Prevention).

## Prevention
- [x] Add indexes for the columns listed above
- [ ] Add a lightweight check (or just a habit/checklist item) that any new
  FK column queried in a hot path gets an index in the same migration that
  introduces it

## Related Issues
- Directly compounds the N+1 query pattern found in the matching engines
  (each of those per-candidate queries is unindexed too)
- Same review pass also found: Standing reputation never recomputed, no
  pagination on list endpoints, and connection-pool sizing that doesn't
  survive horizontal scaling

## References
- `docs/architecture/database_schema_design.md` §2 "Normalization &
  Constraints" — documents unique constraints and FKs, but says nothing
  about indexing strategy at all

---

**Resolved By:** Claude Code (architecture-review-to-fixes session)
**Time to Resolution:** Same day, follow-up session
