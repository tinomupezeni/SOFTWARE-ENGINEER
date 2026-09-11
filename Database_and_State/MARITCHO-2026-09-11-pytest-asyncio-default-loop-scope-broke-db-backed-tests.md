# pytest-asyncio's Default Function-Scoped Event Loop Broke Every DB-Backed Async Test

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`backend/tests/` was empty before this session (see
`2026-09-11-dev-tooling-never-installed.md`), so no one had yet hit this.
Writing the first real integration tests (for the new CORE-001 job-request
endpoint) against the module-level async SQLAlchemy engine in
`app/database.py`, every test after the first failed with `RuntimeError:
Task ... got Future ... attached to a different loop`. `pytest-asyncio`'s
default is a fresh event loop per test function; `asyncpg` connections
(and the SQLAlchemy pool holding them) are bound to the loop they were
created on. Since `app.database.engine` is a single module-level object
shared across the whole test session, its pool's connections got bound to
whichever test's loop created them first, then broke on every subsequent
test running in a new loop.

## Symptoms
- First test in a run would pass; every test after it failed with the
  "attached to a different loop" `RuntimeError` from `asyncpg`.
- Setting only `asyncio_default_fixture_loop_scope = "session"` was not
  enough on its own — failures continued until the test-loop scope was
  also pinned.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `pytest`/`pytest-asyncio` config only
- **Related Components:** `app/database.py` (module-level async engine),
  `backend/tests/conftest.py`
- **Time First Observed:** 2026-09-11, writing the first tests for CORE-001

## Investigation Steps

### 1. Initial Diagnosis
Reproduced reliably: 1 test passes, all following tests in the same run
fail with the loop-mismatch error, regardless of which test ran first.

### 2. Root Cause Analysis
Confirmed via `pip show pytest-asyncio` (1.4.0) that both
`asyncio_default_fixture_loop_scope` and `asyncio_default_test_loop_scope`
exist as config keys. The project's `pyproject.toml` set neither, so both
fixtures and test functions defaulted to per-function event loops while
sharing one process-lifetime `asyncpg`-backed engine — a structural
mismatch, not a flaky test.

## Root Cause
No prior test infrastructure existed to surface this; it's an inherent
conflict between "one shared async engine for the app" and "a fresh event
loop per test" unless the loop scope is explicitly aligned.

## Solution

### Long-term Fix
Added to `backend/pyproject.toml`:
```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "session"
asyncio_default_test_loop_scope = "session"
```
Verified all 11 new tests in `tests/test_jobs.py` pass consistently, in
any order, across multiple runs.

## Prevention
- [x] Config fixed and verified across a full test run
- [ ] Worth a one-line note in `docs/engineering_standards.md`'s Testing
  Contract section so the next person adding async DB tests doesn't
  rediscover this from scratch.

## Related Issues
- [[2026-09-11-dev-tooling-never-installed]]

---

**Resolved By:** Claude Code (CORE-001 implementation)
**Time to Resolution:** Same session
