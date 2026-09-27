# Editing an already-applied initial migration left the dev database on the old schema

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
After correcting the inverted `verdict_only_when_graded` constraint, the migration was fixed by
deleting `0001_initial.py` and regenerating it. That is safe in a test database and silently wrong
in a real one: the dev database had already recorded `attempts.0001_initial` as applied, and
Django skips migrations by *name*. The regenerated file kept the same name, so it was never
re-run — the dev database kept the broken constraint while the test suite, which builds a fresh
database from the current files, passed 18/18 against a schema the running service did not have.

## Symptoms
- Every test passed; the live server returned 500 on `POST /runs` with the original
  `violates check constraint "verdict_only_when_graded"` on a `queued` run
- `python manage.py migrate` reported **"No migrations to apply"** while the database was
  demonstrably not at the state the models described
- `manage.py makemigrations --check` reported "No changes detected" — also clean, because it
  compares models to migration *files*, not to the database

## Environment Details
- **Server/Host:** local dev, `runner/`, Postgres 16 in `runner-db-1`
- **Services Affected:** every environment whose database had already applied the migration
- **Related Components:** `attempts/migrations/0001_initial.py`, `attempts/models.py`
- **Time First Observed:** 2026-09-27, when the first request hit the running server

## Investigation Steps

### 1. Initial Diagnosis
The live server rejected a valid submission with the *already-fixed* constraint error. Since the
model and the test suite were both correct, the remaining suspect was the database itself.

### 2. Root Cause Analysis
Read the constraint straight out of the running database and compared it to the model:

```python
with connection.cursor() as c:
    c.execute("select conname, pg_get_constraintdef(oid) from pg_constraint "
              "where conname like '%verdict%'")
```

```
verdict_only_when_graded => CHECK (((NOT (verdict IS NULL)) OR ((status)::text = 'graded'::text)))
                                                           ^^^ still the inverted form
```

```
graded_run_has_verdict   => CHECK (((verdict IS NULL) OR ((status)::text = 'graded'::text)))
                                                          ^^^ correct
```

One constraint was fixed on disk, the other was not. `migrate` had nothing to do.

### 3. Key Findings
- `migrate` records applied migrations by name. Same name ⇒ already applied ⇒ skipped, regardless
  of content. Editing a migration file in place is invisible to every subsequent `migrate`.
- `makemigrations --check` inspects models vs. files. The files *were* correct, so it was silent.
  It says nothing about the database.
- The test suite builds `test_archcode` from the current files every run, so it validated the
  intended schema and gave no hint that the dev database diverged. Green tests and a broken
  server were simultaneously true.
- Nothing compared the database's actual schema against the models. The only check available was
  manual.

## Root Cause
Using a *test* database as evidence about a *development* database. The two are constructed
differently — one from migration files on every run, one incrementally by recorded name — and
only the first is reproducible. The fix was verified where verification was easiest, which happened
not to be where the failure was.

## Prevention / Rule
**Guardrail:** Never edit an already-applied migration in place. Either add a new numbered
migration, or — for a disposable local database — recreate it and re-run `migrate` in the same
step, so the file edit and the database reset cannot be separated by accident.

The general form: a green test suite is evidence about the schema the tests *build*, not about
any database that already exists. Any environment that has applied migrations needs its own
verification path — for a disposable local dev database, that means a documented reset command
rather than an ad-hoc one-liner typed under pressure.

## Solution

### Immediate Fix
Confirmed the dev database held only disposable data (1 scenario, 0 runs — everything created
during development that day), then recreated it:

```python
# Connected to `postgres`, not `archcode`: DROP DATABASE cannot run from inside the database
# being dropped, and doing so hangs rather than erroring.
conn = psycopg.connect(dbname="postgres", autocommit=True, **creds)
conn.execute("DROP DATABASE IF EXISTS archcode WITH (FORCE)")
conn.execute("CREATE DATABASE archcode")
```

```bash
python manage.py migrate
```

Verified the constraint in the database now matches the model, and re-ran the end-to-end smoke
test against a live server.

### Long-term Fix
`scripts/smoke.py` now exercises a real server against the real development database, so schema
drift between models and the dev database surfaces as a failed smoke test rather than as a
surprise 500.

### Note on the reset itself
The first two attempts to drop the database hung: Django was connected to the database being
dropped. A separate incident in the same session, and worth recording — `DROP DATABASE` from
inside the target database does not fail fast, it blocks.

## Prevention
- [x] Dev database recreated from the corrected migrations
- [x] Constraint verified directly in `pg_constraint`
- [x] `scripts/smoke.py` runs against the real dev database
- [ ] Document a `reset-db` command so recreating the dev database is one step, not a snippet
      reconstructed under pressure
- [ ] Decide the project rule for initial migrations before first real deployment: after that
      point, schema changes must always be new numbered migrations
- [ ] Add a schema-drift check (e.g. comparing `migrate --plan` output against applied state) to
      catch applied-but-divergent migrations

## Related Issues
- `Database_and_State/ARCHCODE-2026-09-27-verdict-check-constraint-inverted-polarity.md` — the
  constraint this entry is about
- `Backend_and_API/ARCHCODE-2026-09-27-app-import-order-broke-uvicorn-startup.md` — the same
  live-server session surfaced this
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md`

## References
- Django records applied migrations by name in `django_migrations`; content is never re-checked
- `makemigrations --check` compares models to files, not to the database

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~20 minutes
