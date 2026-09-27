# pytest-django's transaction-wrapped `db` fixture cannot test code that uses two connections

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
ArchCode's FastAPI layer reaches Django's ORM through
`sync_to_async(thread_sensitive=True)`, which runs on a dedicated executor thread with its own
database connection. pytest-django's default `db` fixture wraps each test in a transaction that
is later rolled back, so its data is uncommitted and invisible to any second connection. Tests
wrote a scenario, the API read a different connection, and got a bare `404` for a scenario that
provably existed. The suite was simultaneously red for three unrelated reasons, and this one
manifested as an application-level "not found" rather than as a test-harness problem, which sent
the investigation down the wrong path twice.

## Symptoms
- `assert 404 == 202` on run submission, with a fixture that had just created a published scenario
- `KeyError: 'id'` — downstream, because the 404 body had no run to unwrap
- `PytestWarning: Error when trying to teardown test databases: OperationalError('database
  "test_archcode" is being accessed by other users DETAIL: There is 1 other session using the
  database.')`
- `RuntimeError: Database … doesn't exist` for tests that touched the database without requesting
  the `db` fixture at all

## Environment Details
- **Server/Host:** local dev, `runner/`
- **Services Affected:** entire API test suite
- **Related Components:** `core/db.py`, `tests/conftest.py`, `tests/test_api.py`
- **Time First Observed:** 2026-09-27, first full `pytest` run

## Investigation Steps

### 1. Initial Diagnosis
A 404 from `POST /runs` implies no matching `Scenario` row. The `scenario` fixture was in the
same module and had returned a `Scenario` instance, so the row was believed to exist.

### 2. Root Cause Analysis
Rather than keep guessing, the two threads were asked directly which database they were on and
what they could see:

```python
def test_diag(scenario):
    with connection.cursor() as cur:
        cur.execute("SELECT current_database()")
        print("main:", cur.fetchone()[0], Scenario.objects.count())

    def in_thread():
        with connections["default"].cursor() as cur:
            cur.execute("SELECT current_database()")
            return cur.fetchone()[0], Scenario.objects.count()

    print("bridge:", asyncio.run(sync_to_async(in_thread, thread_sensitive=True)()))
```

```
--- main thread (fixture wrote here) ---
  db: test_archcode
  scenarios visible: 1
--- bridge thread (app reads here) ---
  db: test_archcode
  scenarios visible: 0
```

### 3. Key Findings
- **Same database name, different data.** That ruled out misconfiguration entirely and pointed at
  transaction visibility.
- The `db` fixture's rows are uncommitted. The bridge thread opens a second connection, and a
  second connection cannot see uncommitted rows. Hence 1 vs 0.
- `transactional_db` commits and cleans up with truncation, so both connections agree.
- Django's `ConnectionHandler` is context-local, so `connections.close_all()` in the test thread
  does **not** close the executor thread's connection. That is what produced the "1 other session"
  teardown error and the missing-test-database errors. Closing had to be dispatched through the
  same `thread_sensitive=True` executor.
- Two tests that hit the database never requested `db` or `transactional_db`, so no test database
  existed at all when they ran.

## Root Cause
An ORM shared across two connections is not compatible with transaction-wrapped test isolation.
The isolation strategy — write in a transaction, roll back afterwards — only works when the code
under test reuses the *same* connection. ArchCode's async bridge deliberately does not: it
dispatches to a thread-sensitive executor, which is the correct production design (it serialises
ORM access so a connection is never closed under a concurrent query). The test harness's
isolation model and the production threading model were mismatched, and the mismatch surfaced as
a false application error.

## Prevention / Rule
**Guardrail:** In a project where the ORM is reached through `sync_to_async(thread_sensitive=True)`,
use `transactional_db` for every test that touches the database — enforced by making the shared
fixture depend on `transactional_db` rather than `db`, so no test can pick the wrong one.

The second half: connection cleanup must run **on the thread that opened the connection**.
Dispatch `close_all` through the same `thread_sensitive=True` executor; calling it in the test
thread is a silent no-op for the bridge's connection.

## Solution

### Immediate Fix
```python
@pytest.fixture(autouse=True)
async def close_django_connections() -> AsyncIterator[None]:
    yield
    connections.close_all()
    await sync_to_async(connections.close_all, thread_sensitive=True)()
```

`scenario` now depends on `transactional_db`, and the two tests that touched the database without
declaring it were given `transactional_db` explicitly. Fixtures moved to `tests/conftest.py` so
the `scenario` fixture is shared rather than re-derived per module.

### Long-term Fix
The `scenario` fixture's docstring records *why* `transactional_db` is load-bearing, so the next
author does not "simplify" it back to `db`.

## Prevention
- [x] `transactional_db` used throughout; `db` no longer referenced
- [x] Cleanup dispatched to the bridge's own executor thread
- [x] Fixtures moved to `tests/conftest.py`
- [x] Two database tests that declared no fixture were fixed
- [x] The autouse closer is `async`, since a sync fixture cannot await the executor close
      (a `RuntimeWarning` about a never-awaited coroutine caught the first attempt)
- [x] `pyproject.toml` records why `pytest-django` and the transactional choice are required
- [ ] Slower than `db` (truncation vs rollback) — revisit if suite runtime becomes a problem,
      and do not "optimise" by reverting to `db`

## Related Issues
- `Database_and_State/ARCHCODE-2026-09-27-verdict-check-constraint-inverted-polarity.md` — a real
  bug red in the same run, masked by this one
- `Backend_and_API/ARCHCODE-2026-09-27-django-lazysettings-drops-lowercase-names.md`
- `Backend_and_API/ARCHCODE-2026-09-27-websocket-replay-cursor-derived-from-max-seq.md`
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md`

## References
- pytest-django: `db` = transaction rollback isolation; `transactional_db` = truncation
- asgiref `sync_to_async(thread_sensitive=True)`: single shared executor thread per context
- Django `ConnectionHandler` is context-local, so per-thread cleanup is required

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~40 minutes
