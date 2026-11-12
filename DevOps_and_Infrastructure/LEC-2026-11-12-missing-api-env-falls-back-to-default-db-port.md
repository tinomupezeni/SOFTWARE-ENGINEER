# Missing apps/api/.env falls back to default Postgres port, failing every DB test

**Date:** 2026-11-12
**Project:** LEC Biotec (lec-biotech-ascend)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Running `npm run api:verify` on a freshly set-up checkout failed all 762
database-touching tests with `connection to server at "127.0.0.1", port 5432
failed: Connection refused`, even though the dev Postgres container was up and
healthy on its documented port.

## Symptoms
- `npm run verify:all` reported "93 passed, 762 errors" — every test that
  touched the database errored, while pure-Python tests (contrast math,
  paynow protocol parsing, etc.) passed.
- The error was a connection refusal on port 5432, not 55432 — the project's
  documented offset dev port (see CLAUDE.md: "dev Postgres (:55432)").
- `docker ps` showed `lec_dev_postgres` correctly bound to
  `127.0.0.1:55432->5432/tcp`.

## Environment Details
- **Server/Host:** local dev machine, fresh `npm run setup` + `npm run
  services:up`
- **Services Affected:** `apps/api` test suite (`api:verify`), and by
  extension any Django management command run locally
- **Related Components:** `apps/api/config/settings/base.py`
  (`environ.Env.read_env(BASE_DIR / ".env")`), `apps/api/.env.example`
- **Time First Observed:** first `npm run verify:all` run after `npm run
  api:install` on a clean clone

## Investigation Steps

### 1. Initial Diagnosis
Checked `docker ps` — the dev Postgres container was healthy and listening on
55432 as documented. So the test runner itself was misconfigured, not the
container.

### 2. Root Cause Analysis
```bash
grep -rn "read_env" apps/api/config/settings/*.py
# apps/api/config/settings/base.py:24:environ.Env.read_env(BASE_DIR / ".env")
ls apps/api/.env       # No such file
ls apps/api/.env.example   # present, DB_HOST=127.0.0.1 DB_PORT=55432
```
Django's settings read `apps/api/.env`, not the repo-root `.env` (which is a
different, production-flavored file with `DB_HOST=postgres DB_PORT=5432` for
the Docker Compose network). With no `apps/api/.env` present, `django-environ`
silently falls back to its own defaults (`DB_PORT=5432`), which is the default
Postgres port — not the project's offset dev port.

### 3. Key Findings
- There are two unrelated `.env` files in this repo: the root one (production
  container network, `DB_HOST=postgres`) and `apps/api/.env` (host-side dev,
  `DB_HOST=127.0.0.1`, `DB_PORT=55432`). Only the latter is read by Django.
- `apps/api/.env` is never created automatically — `npm run api:install`
  installs the Python venv but does not copy `.env.example` → `.env`.
- `npm run setup` does not create it either, so a fresh clone's first
  `verify:all` run fails the entire API gate unless the developer manually
  copies the example file first.

## Root Cause
`apps/api/.env` is required for Django to pick up the dev Postgres/Redis
connection details, but no onboarding script (`npm run setup`,
`npm run api:install`) creates it from `apps/api/.env.example`, so a fresh
checkout silently falls back to `django-environ`'s built-in defaults
(port 5432) instead of failing loudly or self-provisioning.

## Prevention / Rule
**Guardrail:** `scripts/py.mjs` (or `npm run api:install`) should copy
`apps/api/.env.example` to `apps/api/.env` on first run when the target file
does not yet exist, the same way `scripts/py.mjs` already creates the
virtualenv on first use.

This closes the gap because the failure mode is silent (a wrong default, not
a crash) — nothing stops a developer from believing the test suite itself is
broken rather than their environment.

## Solution

### Immediate Fix
```bash
cp apps/api/.env.example apps/api/.env
```
Re-ran `npm run api:verify`: 855/855 tests passed, 94% coverage.

### Long-term Fix
Add a first-run copy step to `npm run setup` / `scripts/py.mjs`, gated on
`apps/api/.env` not already existing (never overwrite a developer's existing
file).

## Prevention
- [x] Configuration changes needed — none; fix is a one-time local copy
- [ ] Monitoring/alerts to add — n/a (dev-only)
- [ ] Documentation to update — CLAUDE.md could note `apps/api/.env` is
      required and distinct from the root `.env`
- [ ] Code changes required — auto-copy `.env.example` on first
      `api:install`/`setup` run

## Related Issues
- None on file.

## References
- `apps/api/config/settings/base.py`
- `apps/api/.env.example`
- `docker-compose.dev.yml`

---

**Resolved By:** tinomupezeni (with Claude Code)
**Time to Resolution:** ~15 minutes
