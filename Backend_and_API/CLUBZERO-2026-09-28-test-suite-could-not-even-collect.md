# The entire backend test suite has been uncollectible — `Base` was imported from the wrong module and `aiosqlite` was never declared as a dependency

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** High (no one could have run `pytest` successfully in this state — the 3 existing test files were never actually exercised locally as-is)
**Status:** Resolved

## Summary
While verifying fixes for three other Club Zero bugs (mobile check-in
endpoint mismatch, missing seats membership check, broken refresh-token
flow), running `pytest tests/` failed before a single test executed:
`tests/conftest.py` imports `Base` from `app.database`, but `Base` is
actually defined in `app.models` (`club-zero-backend/app/database.py`
never defines or re-exports it) — an immediate `ImportError` during
collection. After fixing that import, collection still failed because
`conftest.py`'s in-memory test database URL
(`sqlite+aiosqlite:///:memory:`) requires the `aiosqlite` package, which
is used nowhere else in the app and was never added to
`requirements.txt`.

## Symptoms
- `python -m pytest tests/` failed immediately with
  `ImportError: cannot import name 'Base' from 'app.database'`, before
  any of `test_auth.py` / `test_clubs.py` / `test_checkins.py` could run.
- After fixing that import, `ModuleNotFoundError: No module named
  'aiosqlite'` on the very next line (`create_async_engine(TEST_DATABASE_URL, ...)`).
- This means the existing test suite — despite reading as correct and
  well-scoped — had never actually been run to completion in a fresh
  checkout with `pip install -r requirements.txt`, since neither error
  would occur until `aiosqlite` is manually installed on top of that.

## Environment Details
- **Server/Host:** Local dev (FastAPI backend)
- **Services Affected:** `club-zero-backend/tests/conftest.py`,
  `club-zero-backend/requirements.txt`
- **Related Components:** All three test files
  (`test_auth.py`, `test_clubs.py`, `test_checkins.py`) — none could run.
- **Time First Observed:** 2026-09-28, while verifying fixes for three
  other logged Club Zero issues.

## Investigation Steps

### 1. Initial Diagnosis
Ran `python -m pytest tests/ -q` inside the project's own `venv` to
confirm the check-in and seats-membership fixes didn't break anything.

### 2. Root Cause Analysis
```python
# tests/conftest.py:5 (before fix)
from app.database import Base, engine, get_db_session
# app/database.py only defines engine, AsyncSessionLocal, get_db_session — no Base
# app/models.py:7 — Base = declarative_base()  <- the actual definition
```
```
requirements.txt has pytest, pytest-asyncio, httpx — no aiosqlite,
despite conftest.py hard-coding a sqlite+aiosqlite:// test DB URL.
```

### 3. Key Findings
- Both defects are independent of each other and of the three bugs
  originally being verified — this is pre-existing test infrastructure
  rot, not something introduced by this session's fixes.
- Once both were fixed, the suite ran and (combined with the
  `uuid.UUID` fix in [[CLUBZERO-2026-09-28-str-vs-uuid-query-mismatch]]
  and a locally-run Redis container for the check-in test's Redis
  publish) all 9 tests passed.

## Root Cause
`tests/conftest.py` was written against an assumed module layout
(`Base` in `database.py`) that doesn't match the actual one (`Base` in
`models.py`), and the test-only `aiosqlite` dependency was never added
to `requirements.txt` when the SQLite-backed test config was written.

## Prevention / Rule
**Guardrail:** Run the test suite in CI (or as part of any code-review
checklist item) starting from a clean `pip install -r requirements.txt`
in a fresh virtualenv — never a locally-hydrated venv with extra
packages installed ad hoc — so an uncollectible suite or a missing test
dependency fails immediately instead of silently accumulating.

Neither gap could have been caught by running tests inside an
already-populated dev venv that happened to have `aiosqlite` installed
from some earlier, unrelated work — only a from-scratch install
surfaces a missing requirements.txt entry.

## Solution

### Immediate Fix
- `tests/conftest.py`: changed `from app.database import Base, engine, get_db_session`
  to `from app.database import engine, get_db_session` +
  `from app.models import Base`.
- `requirements.txt`: added `aiosqlite==0.20.0`.

### Long-term Fix
Add a CI job that installs from `requirements.txt` in a clean
environment and runs `pytest`, so this class of drift is caught on the
next PR rather than the next person who happens to try running tests
locally.

## Prevention
- [x] Fix `Base` import in `conftest.py`
- [x] Add `aiosqlite` to `requirements.txt`
- [ ] Add a CI workflow that runs `pytest` from a clean install
- [ ] Documentation to update

## Related Issues
- [[CLUBZERO-2026-09-28-str-vs-uuid-query-mismatch]] — found immediately
  after this fix, while the same test run was still failing.

## References
- `club-zero-backend/tests/conftest.py`
- `club-zero-backend/requirements.txt`
- `club-zero-backend/app/database.py`
- `club-zero-backend/app/models.py`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.
