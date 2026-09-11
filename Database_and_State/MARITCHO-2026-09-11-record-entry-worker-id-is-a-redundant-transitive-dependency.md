# `RecordEntry.worker_id` Duplicates `Job.worker_id` With No DB-Level Constraint Tying Them Together

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
`RecordEntry.worker_id` is fully derivable via `RecordEntry.job_id →
Job.worker_id` — the job a record entry belongs to already has exactly one
assigned worker by the time a record entry can exist (only reachable from
`IN_PROGRESS`, which requires a prior `BOOKED` state that sets
`Job.worker_id`). Storing `worker_id` again on `RecordEntry` is a
transitive dependency: a non-key attribute (`worker_id`) depends on another
non-key attribute (`job_id`) rather than directly on the table's own key.
Nothing in the schema enforces the two must agree.

## Symptoms
- `app/models.py`: `RecordEntry.job_id` (FK to `jobs.id`, unique) and
  `RecordEntry.worker_id` (FK to `persons.id`) are both stored, with no
  `CHECK`/trigger ensuring `RecordEntry.worker_id == Job.worker_id` for the
  referenced job.
- `app/routers/jobs.py::complete_job` does set
  `worker_id=job.worker_id` correctly at creation time — so in practice,
  by application-code discipline, the two never actually disagree today.
  The gap is that nothing at the *database* level would catch it if a
  future code path ever passed the wrong value.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/models.py` (`RecordEntry`)
- **Related Components:** `app/routers/jobs.py::complete_job` (the only
  writer)
- **Time First Observed:** 2026-09-11, DB normalization review requested
  directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Checked whether any denormalization (duplicated, derivable data) exists in
the otherwise-3NF-compliant schema.

### 2. Root Cause Analysis
This is a common, often-acceptable trade-off: keeping `worker_id` directly
on `RecordEntry` avoids an extra join whenever the record needs to be read
independently of its `Job` (e.g., "show me everything this worker has ever
done," which would otherwise require joining through `jobs`). The design
doc doesn't say whether this was a deliberate read-optimization or simply
copied from the `Job` row without considering the redundancy — either is
plausible.

### 3. Key Findings
- Low real-world risk today: there's exactly one writer
  (`complete_job`), and it always derives the value correctly from
  `job.worker_id`. This is a design-hygiene finding, not an active bug.

## Root Cause
Either a deliberate (but undocumented) denormalization for read
convenience, or an oversight — can't be determined from the docs alone.

## Solution

### Immediate Fix
Put the three options (keep + trigger, keep + document only, drop the
column) to the user. Answer: **keep the column and add a DB-level
guarantee** — the denormalization is genuinely useful (worker-scoped
record queries without a join through `jobs`), so the fix is to close the
enforcement gap, not remove the convenience.

Implemented, same day:
- New migration `a8bea2064338`: a `check_record_entry_worker_matches_job()`
  trigger function, attached as a `BEFORE INSERT` trigger on
  `record_entries`, that looks up the referenced job's `worker_id` and
  `RAISE EXCEPTION`s if it doesn't match `NEW.worker_id`. `INSERT`-only is
  intentional and sufficient: `record_entries` is already immutable
  (`prevent_mutation()`, `989350a9dd8d`), so there is no `UPDATE` path
  that could desync the two values after the fact.
- Verified directly against Postgres (not just "the migration ran"): a
  scripted `DO` block inserted a job with one worker, then attempted a
  `record_entries` insert with a *different* worker_id for that job —
  rejected with the expected error message naming both IDs — and then a
  second insert with the matching `worker_id` — accepted. Both run inside
  a transaction that's rolled back afterward, confirmed via a follow-up
  query that no test rows were left behind.
- Full round-trip verified: `alembic downgrade -1` → `alembic upgrade
  head` → `alembic check`, all clean.
- Documented the reasoning in `docs/architecture/database_schema_design.md`
  new §2.9 (why the denormalization exists, and that it's now enforced at
  INSERT), the ERD annotation on `RECORD_ENTRIES.worker_id`, and mirrored
  the trigger + explanatory comments into `docs/architecture/schema.sql`.
- Verified: `ruff check .` / `mypy .` clean (43 files); full suite green
  (92 passed, 92.86% coverage) — the one real writer (`complete_job`)
  already sets `worker_id` correctly, so no test needed to change.

### Long-term Fix
Done — the redundancy is now a documented, DB-enforced decision rather
than an unconstrained duplication. No further action needed unless a
second writer of `record_entries` is ever introduced, in which case this
trigger already protects it.

## Prevention
- [x] Decided (with the user) and documented that the denormalization is
  intentional, in `database_schema_design.md` §2.9
- [x] Added a DB-level consistency guarantee (`BEFORE INSERT` trigger) so
  a future code path can't silently pass a mismatched `worker_id`

## Related Issues
- Same normalization review that found the `grade` and
  guarantor/next-of-kin inconsistencies

---

**Resolved By:** Claude Code (architecture-review-to-fixes session), design
decision confirmed by the user
**Time to Resolution:** Same day, follow-up session
