# Test Suite's Admin DSN Was Hardcoded to localhost:5432, Then Broke Again via SQLAlchemy's Password Masking

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development (would have broken CI on first run)
**Severity:** Medium
**Status:** Resolved

## Summary
While wiring up GitHub Actions CI, validated the new workflow by hand
against genuinely fresh Postgres/Redis containers on non-default ports
(55433/6380) rather than trusting the long-lived local dev containers on
5432/6379 that every test run this whole project had ever used. All 86
tests failed. Two distinct, stacked bugs were hiding behind "it always
works locally": `tests/conftest.py`'s admin connection (used to
`CREATE DATABASE maricho_test`) was hardcoded to `localhost:5432` regardless
of the actual `DATABASE_URL`, and — once that was fixed to derive from
`DATABASE_URL` — the derivation itself broke because `str(sqlalchemy_url)`
masks the password as `***` by design.

## Symptoms
- First fix attempt (deriving `ADMIN_DSN` from `DATABASE_URL` via
  `str(url.set(database="postgres"))`): all 86 tests errored with
  `asyncpg.exceptions.InvalidPasswordError: password authentication failed
  for user "postgres"`.
- Direct `asyncpg.connect(...)` with the same host/port/credentials, typed
  out explicitly, worked fine — ruling out the containers themselves.
- Isolated it to `str(url)` literally rendering `postgres:***@host:port/db`
  — SQLAlchemy's `URL.__str__` hides the password by default; only
  `render_as_string(hide_password=False)` returns the real one.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`,
  simulating CI with temporary `docker run` containers on ports 55433/6380
- **Services Affected:** `tests/conftest.py` (`ADMIN_DSN`, `TEST_DB_NAME`)
- **Related Components:** `.github/workflows/backend-ci.yml` (this is what
  the bug would have broken on the very first push)
- **Time First Observed:** 2026-09-11, validating the new CI workflow

## Investigation Steps

### 1. Initial Diagnosis
`docker run` fresh Postgres 15 + Redis 7 containers on ports 55433/6380 (to
avoid touching the real dev containers), exported `DATABASE_URL`/`REDIS_URL`
pointing at them, ran `pytest --cov`. Every test failed at the session-scope
database-creation fixture.

### 2. Root Cause Analysis
- `ADMIN_DSN` was a module-level constant:
  `"postgresql://postgres:postgres@localhost:5432/postgres"` — completely
  independent of `DATABASE_URL`. It happened to always match because every
  session so far (dev, and this project's own docker-compose) used
  port 5432. The moment Postgres lived anywhere else (CI, or these
  temporary containers), `_ensure_test_database()` silently created
  `maricho_test` on the **wrong Postgres instance** (whichever one actually
  answers on 5432), then `alembic upgrade` — correctly targeting
  `DATABASE_URL` — ran against a database that was never created there.
- After parameterizing `ADMIN_DSN` from `DATABASE_URL` via
  `sqlalchemy.engine.make_url(...).set(database="postgres")`, converting
  back to a string with plain `str(...)` triggered SQLAlchemy's built-in
  password redaction (a deliberate safety feature for logging URLs) —
  so the "fixed" DSN carried the literal string `***` as its password.

## Root Cause
Two independent shortcuts (a hardcoded connection target, and using the
wrong string-conversion method on a `URL` object) each individually looked
correct under the only conditions ever actually tested — a single
long-lived local Postgres on the default port.

## Solution

### Long-term Fix
In `tests/conftest.py`:
```python
_test_db_url = make_url(os.environ["DATABASE_URL"])
TEST_DB_NAME = _test_db_url.database
ADMIN_DSN = _test_db_url.set(drivername="postgresql", database="postgres").render_as_string(
    hide_password=False
)
```
Verified by running the full suite (`pytest --cov`, 86 tests) twice: once
against fresh, temporary Postgres/Redis containers on non-default ports,
once against the normal local dev setup — both green, both hitting the
85% coverage gate (92.55%).

## Prevention
- [x] Verified against both a fresh non-default-port environment and the
  normal local one
- [x] This exact scenario (fresh containers, non-default ports) is now
  literally what `.github/workflows/backend-ci.yml` does on every run, so
  it can't quietly regress back to "only works locally" unnoticed

## Related Issues
- [[2026-09-11-dev-tooling-never-installed]]
- [[2026-09-11-pytest-asyncio-default-loop-scope-broke-db-backed-tests]]

---

**Resolved By:** Claude Code (packaging/CI session)
**Time to Resolution:** Same session, caught before ever reaching real CI
