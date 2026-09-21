# republish_canonical exits 1 under pgbouncer despite doing all its work

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging (applies to any pgbouncer-fronted environment, i.e. also production)
**Severity:** Medium
**Status:** Resolved

## Summary
`python manage.py republish_canonical --entities subject` on staging queued
and republished all 171 subjects correctly, then crashed with
`psycopg.errors.InvalidCursorName: cursor "..." does not exist` while
closing the queryset's server-side cursor, exiting with code 1. Every row
had already been individually saved before the crash, so the command's
actual job succeeded — but its exit code says otherwise, which would fail
a script or CI step checking the return code, or make an operator think the
republish did nothing.

## Symptoms
```
psycopg.errors.InvalidCursorName: cursor "_django_curs_134759113204544_sync_1" does not exist
```
raised from `cursor.close()` inside Django's `QuerySet.iterator()` cleanup,
after the command had already logged `Outbox queued subject.updated: ...`
171 times (one per row) and reached the end of the loop.

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142)
- **Services Affected:** Admin Backend replication tooling
- **Related Components:** `hbec-pgbouncer-staging` / `hbec-main-pgbouncer-staging` (`edoburu/pgbouncer:v1.24.1-p1`)

## Investigation Steps

### 1. Initial Diagnosis
Re-ran the command capturing full output: `grep -c "Outbox queued subject"`
showed exactly 171 lines (the full subject count) before the traceback,
so the loop body had completed for every row — the exception fires only in
cursor teardown, not mid-work.

### 2. Root Cause Analysis
`qs.iterator()` opens a **named server-side cursor** on Postgres. Every
statement in this stack goes through pgbouncer in front of Postgres. Under
transaction-pooling (the mode this deployment uses for pgbouncer), a client
session can be handed a *different* backend server connection for its next
statement once the current implicit transaction ends — a named cursor,
however, lives on one specific backend connection. If the cursor's `CLOSE`
statement lands on a different backend than the one that opened it, Postgres
correctly reports the cursor doesn't exist there.
`republish_canonical.handle()` has no `transaction.atomic()` wrapping the
loop, so each `instance.save()` autocommits individually — that's exactly
the kind of connection churn that triggers the pooling mismatch on cleanup.

### 3. Key Findings
- Purely a cleanup-time failure; no data was lost or rolled back, because
  nothing here depended on a single open transaction across all 171 saves.
- This isn't specific to `--entities subject` — the same `qs.iterator()`
  pattern is used for `exam_board`, `grade`, and `topic` too, so any of
  those (1214 topics in this run) would hit it under the same conditions.

## Root Cause
`.iterator()`'s server-side cursor is incompatible with pgbouncer
transaction-pooling once the connection can be recycled between the cursor's
open and its close — which autocommit-per-`save()` guarantees will happen
on any non-trivial queryset.

## Prevention / Rule
**Guardrail:** don't use `QuerySet.iterator()` for any management command
running against a pgbouncer-in-transaction-pooling connection unless the
whole loop is wrapped in a single `transaction.atomic()` that keeps one
backend connection for the cursor's full lifetime. For the entity counts
these replication commands actually deal with (hundreds, not millions of
rows), the simplest fix is to not use `.iterator()` at all.

## Solution

### Immediate Fix
`ADMIN/adminBackend/apps/replication/management/commands/republish_canonical.py`:
replaced `for instance in qs.iterator():` with `for instance in qs:`,
commit `da9354f0`. Verified on staging: `republish_canonical --entities
exam_board grade topic` now exits 0 and republishes cleanly (1214 topics in
that run).

### Long-term Fix
Audit other management commands for the same `.iterator()` pattern against
a pgbouncer-fronted connection; none currently known, but this pattern was
copy-pasteable.

## Prevention
- [x] Fix applied and deployed to staging
- [ ] Grep the rest of the codebase for `.iterator()` usage against models
      backed by pgbouncer-pooled connections

## Related Issues
- `Database_and_State/HBEC-2026-09-21-staging-student-subject-drift.md` —
  the issue this command was being used to fix when the crash was found

## References
- `ADMIN/adminBackend/apps/replication/management/commands/republish_canonical.py`

---

**Resolved By:** Claude Sonnet 5 (with tinomupezeni)
**Time to Resolution:** ~10 minutes
