# Blue-Green Phase 1: Real Expand/Contract Migration Test Against the Shared Database

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Architecture Decision Validation
**Status:** Completed

## Summary
Ran a real Django migration pair (expand, then contract) against the
isolated blue-green dry-run's shared database, deliberately applied
out-of-step between the two colors, to validate two things discussed
earlier in this session but not yet proven: that an additive (expand)
migration is safe to apply to only one color while the other keeps running
unmodified, and that the DB-trigger dual-write design recommended for
column-rename-style migrations survives every write path — ORM `.save()`,
a Django `QuerySet.update()`-style bulk statement, and raw SQL — not just
the ORM path a naive test would check. Also deliberately reproduced the
contract-phase failure mode (dropping a column while something still
depends on it) to make the risk concrete rather than theoretical. All
changes were reverted; production was untouched throughout.

## Context / Trigger
Direct continuation of
[`HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md`](HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md),
whose own "Follow-ups" section named this as the next concrete step: Phase
1 had proven an *already-applied* schema works identically for both
colors, but had not yet exercised a genuinely new migration landing while
the two colors are out of sync — the actual risk scenario blue-green
exists to manage. User asked directly to "test a real migration against
this setup."

This also closes the loop on an earlier architecture discussion this
session: two approaches were weighed for safely renaming a column under
blue-green (Approach 1: dual-write in application code; Approach 2: a DB
trigger), and Approach 2 was recommended specifically because triggers
fire regardless of write path — including bulk `.update()` calls that
bypass Django signals, which was the exact root cause of a real production
bug earlier this session (`merge_duplicate_subjects.py`). That
recommendation had not yet been tested against a real, running trigger.

## Scope
**Included**: a real two-migration pair (`0032` expand, `0033` contract)
against `accounts_user` in the shared dry-run database; applying them to
only one color (green) while the other (blue) ran unmodified; testing
writes from both colors via raw SQL, and a true multi-row bulk `UPDATE`
simulating `QuerySet.update()`; deliberately reproducing the contract-phase
failure.

**Explicitly excluded**: these migrations were never added to the
`apps/accounts/migrations/` directory in the repository, and the
`bluegreen_test_old`/`bluegreen_test_new` fields were never added to
`models.py`. The whole test was schema-only and fully reverted — nothing
here is a real feature or a real planned column rename; it is a rehearsal
of the mechanic using disposable, meaningless field names, injected
directly into the dry-run containers via `docker cp` and deleted
afterward.

## Method
1. Wrote the migration pair locally (not in the repo), matching the real
   app's actual migration chain (`dependencies` pointing at the real
   `0031_emailbounce`, the most recent migration in the codebase).
2. Copied migration `0032` into the **green** container only via
   `docker cp`, leaving blue with no knowledge of it, and applied it there
   with `manage.py migrate accounts 0032`.
3. At each step, verified the actual resulting state rather than trusting
   a command's own success message: inspected the live schema and
   trigger directly in Postgres, checked what blue's own
   `showmigrations` reported, and ran a real ORM read plus a real
   `/health/live/` check against blue to confirm the schema change
   underneath it caused no breakage.
4. Simulated blue ("old code," writes only the old-named column) and green
   ("new code," writes only the new-named column) each performing a raw
   `UPDATE`, confirming the trigger synced both directions.
5. Simulated the exact bug class that motivated choosing triggers over
   application-level dual-writing: a single multi-row `UPDATE` statement
   with no ORM instance involved at all (what `QuerySet.update()` and
   `merge_duplicate_subjects.py`'s bulk `.update()` actually generate at
   the SQL level), confirmed the trigger fired for every affected row.
6. Applied the contract migration (`0033`, drops the trigger and the old
   column) to green, then **deliberately repeated** the exact "old code"
   write that had just succeeded moments earlier, to observe the failure
   directly instead of reasoning about it abstractly.
7. Reverted both migrations (`migrate accounts 0031`), deleted the
   injected migration files, and verified the schema, both colors'
   health, and real production were all back to/still at baseline.

## Decisions & Findings

### Expand-phase migrations are genuinely safe under color skew
Applying `0032` to green only and leaving blue completely unaware of it
(no migration file, no model field) caused zero disruption to blue: its
`showmigrations` doesn't even list `0032` as a possibility (it only
enumerates migrations present in its own migration directory), its ORM
reads succeeded normally, and `/health/live/` returned 200 throughout.
This confirms, with a real migration rather than an assumption, that
Django's ORM only ever selects/writes the columns it knows about from its
own model state — an extra column neither process's code references is
invisible to it, regardless of the shared table.

### Migration state is DB-level, not container-level — a nuance worth knowing
`django_migrations` is a shared table in the shared database. The instant
green ran `migrate`, the row for `0032` existed as applied — a fact true
of the *database*, independent of which container's filesystem holds the
migration file. Blue's own `showmigrations` output doesn't reflect this at
all (it can't list a migration it has no file for), so **"has this
container been upgraded" cannot be inferred from the shared migration
table** — that table tracks schema state, not code deployment state. A
real blue-green rollout needs its own signal for "which colors are running
code that expects this schema," separate from Django's own bookkeeping.

### The trigger-based dual-write recommendation holds under the exact failure mode it was chosen for
A true multi-row `UPDATE` statement, issued with no Django model instance
involved at all, synced both columns on every affected row. This is not
just "the ORM path works" — it is the specific scenario
(`merge_duplicate_subjects.py`'s bulk `.update()` silently not firing
signals) that caused a real production incident earlier this session, now
reproduced on purpose against a trigger and confirmed handled. This is
evidence for the earlier recommendation, not just restated reasoning.

### The contract-phase danger is real and immediate, not theoretical
Writing to the old column succeeded cleanly one command before the
contract migration ran, and failed with
`django.db.utils.ProgrammingError: column "bluegreen_test_old" of relation
"accounts_user" does not exist` one command after — on the exact same
simulated "old code" write. In a real deployment this is a live 500 to a
real user, the instant any code path that hasn't cut over tries to touch
the dropped column. This is the concrete version of the abstract rule
already written into `HBEC/CLAUDE.md`'s migration discipline: a contract
migration must not ship until every live code path (not just "the other
color," but every running instance of every color) has stopped
referencing the old column.

## Changes Made
No permanent changes anywhere. Two throwaway migration files existed only
inside `bg-student-backend-green`'s container filesystem for the duration
of the test, were applied and then reverted against the isolated dry-run
database only, and were deleted before the test concluded. Nothing was
added to the HBEC repository, to `models.py`, or to any environment other
than the disposable `/sdb-disk/hbec-bluegreen/` dry-run.

## Verification
- Schema confirmed clean afterward: no `bluegreen_test_*` columns, no
  `bluegreen_test_sync_trigger`, via direct `psql \d` and
  `pg_trigger` queries.
- Both `bg-student-backend-blue` and `bg-student-backend-green` returned
  `200` from `/health/live/` after the full revert.
- Real production confirmed untouched throughout: `hbec-student-backend`
  and `hbec-postgres` container start timestamps unchanged from before
  this test began, `https://student.hbca.tech/` returned `HTTP/2 200` at
  the final check.

## Follow-ups / Deferred
- This test used disposable field/trigger names with no real feature
  behind them. A real column-rename migration, when one is actually
  needed, should follow this same proven expand → dual-write-via-trigger →
  cutover → contract sequence, with the guardrails already named in this
  session's earlier discussion (scoped trigger lifecycle — create in the
  expand migration, write the drop migration at the same time; heavy
  inline documentation; explicit non-precedent framing so this doesn't
  become an ad-hoc pattern elsewhere in the codebase).
- Not yet tested: a genuinely different **code version** running on green
  vs. blue (this test changed schema only, not application code) — the
  next logical step per the Phase 1 report's own follow-ups.
- Not yet tested: what a real deploy's automated migration-on-boot
  (`migrate --noinput` at container startup) does when it hits a pending
  migration automatically, rather than being driven by hand via
  `manage.py migrate` as this test did.

## References
- [`HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md`](HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md) — the infrastructure this test ran against.
- `HBEC/CLAUDE.md`'s expand/contract and migration-discipline notes
  (documented production incidents this test's contract-phase
  demonstration directly illustrates).

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session (2026-10-01), continuing directly from the Phase 1 build-out.
