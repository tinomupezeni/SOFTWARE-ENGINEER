# sqlite local dev unconditionally requires psycopg2 via django.contrib.postgres

**Date:** 2026-11-04
**Project:** SWAP-O-SELL
**Environment:** Development
**Severity:** Low
**Status:** Workaround Applied

## Summary
First local (non-Docker) run of the backend on a fresh machine. `DATABASES`
defaults to sqlite and no `DATABASE_URL` was set, but Django still failed to
boot with `ModuleNotFoundError: No module named 'psycopg2'` because
`django.contrib.postgres` is listed unconditionally in `INSTALLED_APPS`.

## Symptoms
- `python manage.py migrate` crashed during `django.setup()` / app registry
  population, not during any DB connection attempt — i.e. it failed before
  sqlite was ever touched.
- Traceback pointed at `django/contrib/postgres/apps.py` importing
  `django.db.backends.postgresql.psycopg_any`, which imports `psycopg2`.

## Environment Details
- **Server/Host:** local dev machine (no Docker, no `.env`)
- **Services Affected:** `backend` (Django/DRF)
- **Related Components:** `swaposell/settings.py` `INSTALLED_APPS`,
  `modules/listings/views.py` (uses `TrigramSimilarity` from
  `django.contrib.postgres.search`, guarded by `if connection.vendor ==
  'postgresql'`)
- **Time First Observed:** 2026-11-04, first local backend boot

## Investigation Steps

### 1. Initial Diagnosis
Ran `python manage.py migrate --noinput` with a freshly created venv and
`requirements.txt` installed (minus `psycopg2-binary`, which failed to
build from source — no `pg_config` on this machine). Expected it to just
work since `DATABASES["default"]["ENGINE"]` defaults to sqlite3.

### 2. Root Cause Analysis
```bash
grep -n "postgres\|INSTALLED_APPS" -A30 backend/swaposell/settings.py
```
`"django.contrib.postgres"` is present in `INSTALLED_APPS` with no
conditional guard, unlike its one actual use site
(`modules/listings/views.py`), which already correctly gates
`TrigramSimilarity` behind `connection.vendor == 'postgresql'`.

### 3. Key Findings
- `django.contrib.postgres.apps` imports `psycopg2` at import time, as soon
  as the app is in `INSTALLED_APPS` — regardless of which DB engine is
  actually configured.
- The rest of the codebase already treats sqlite as a first-class local/dev
  backend (default `DATABASES`, trigram search explicitly feature-gated),
  so this app entry is the only place sqlite-only dev is blocked on having
  a Postgres driver installed.

## Root Cause
`django.contrib.postgres` was added to `INSTALLED_APPS` unconditionally for
the one Postgres-only feature (trigram search), instead of only adding it
when the configured DB is actually Postgres. This silently couples sqlite
dev environments to a Postgres driver dependency they don't otherwise need.

## Prevention / Rule
**Guardrail:** Make `"django.contrib.postgres"` conditional on the resolved
DB engine, e.g. `if DATABASES["default"]["ENGINE"].endswith("postgresql"):
INSTALLED_APPS.append("django.contrib.postgres")`, computed after
`DATABASES` is resolved in `settings.py`.

This closes the gap directly: the app (and its `psycopg2` import) is only
ever loaded when a Postgres connection is actually configured, matching the
existing `connection.vendor == 'postgresql'` guard already used at the one
call site.

## Solution

### Immediate Fix
Installed an unpinned `psycopg2-binary` (the pinned `2.9.10` has no wheel
for Python 3.14, which is the only interpreter available on this machine)
so the app boots. This is a workaround, not a fix — sqlite dev still
requires the Postgres driver to be present.

```bash
.venv/bin/pip install -q psycopg2-binary   # unpinned; 2.9.10 has no py3.14 wheel
```

### Long-term Fix
Gate `django.contrib.postgres` in `INSTALLED_APPS` on the actual DB engine
as described above, so sqlite-only dev never needs `psycopg2` installed.

## Prevention
- [ ] Configuration changes needed — gate `django.contrib.postgres` on DB engine
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — note Python version constraints for
      `requirements.txt` pins if the team moves to newer interpreters
- [ ] Code changes required — `backend/swaposell/settings.py`

## Related Issues
- None filed yet.

## References
- `backend/swaposell/settings.py` (`INSTALLED_APPS`)
- `backend/modules/listings/views.py` (existing `connection.vendor ==
  'postgresql'` guard for `TrigramSimilarity`)

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~10 minutes (workaround only)
