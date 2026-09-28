# Check-in tests 500 under pytest without a host-reachable Redis — realtime publish had no test seam

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** Medium (2 of 9 existing tests red on any checkout without extra local infra)
**Status:** Resolved

## Summary
`tests/test_checkins.py::test_check_in_success` and
`test_check_in_duplicate_prevented` failed with
`redis.exceptions.ConnectionError` because every check-in request calls
`app/realtime.py::_publish`, which opens `redis://localhost:6379` — but the
compose Redis has no host port mapping, so nothing is listening there from
a local pytest run. The previous session worked around this with a
locally-run Redis container; this entry records the permanent fix (a
hermetic test seam), so the suite is green from a plain `pytest` again.

## Symptoms
- `venv/bin/python -m pytest tests/ -q` → `2 failed, 7 passed`.
- Both failures: `redis.exceptions.ConnectionError: Error 111 connecting
  to localhost:6379` surfacing as HTTP 500 on `POST /clubs/{id}/check-in`.
- The 7 passing tests were the ones whose code paths never touch
  `_publish` (auth, clubs, seats reads, nudges, device registration).

## Environment Details
- **Server/Host:** Local dev, `club-zero-backend/venv` (Python 3.14)
- **Services Affected:** `app/realtime.py::_publish`, `tests/conftest.py`,
  `tests/test_checkins.py`
- **Related Components:** `app/redis.py` (`REDIS_URL` defaults to
  `redis://localhost:6379`); `docker-compose.yml` (Redis has no host port
  mapping — reachable only inside the compose network, per `DEVLOG.md` §3)
- **Time First Observed:** 2026-09-28, while establishing the pre-change
  baseline for the habits/nudges coverage work.

## Investigation Steps

### 1. Initial Diagnosis
Ran the suite after installing the missing `firebase-admin` dependency
(collection was failing on `import firebase_admin` before any test ran).
Result: 7 passed, 2 failed — both check-in tests, both Redis connection
errors.

### 2. Root Cause Analysis
```bash
venv/bin/python -c "import redis.asyncio as r, asyncio; \
  print(asyncio.run(r.from_url('redis://localhost:6379').ping()))"
# redis.exceptions.ConnectionError: Error 111 connecting to localhost:6379
docker ps --format 'table {{.Names}}\t{{.Status}}'
# club-zero-backend-redis-1 Up 10 hours  <- running, but host-unreachable by design
```
Traced the call chain: `POST /check-in` → `notify_check_in_completed`
→ `_publish` → `get_redis_client()` → `redis.publish(...)` against
`localhost:6379`. `aioredis.from_url` connects lazily, so the failure only
materializes at `publish` time — i.e. only on write paths, which is why
reads (seats) and non-notifying writes (nudges) passed.

### 3. Key Findings
- Pre-existing, not introduced by the coverage work: any fresh checkout
  running `pytest` without a hand-rolled local Redis gets these 2
  failures.
- The prior session's workaround (run a Redis container on the host port)
  is documented in
  [[CLUBZERO-2026-09-28-test-suite-could-not-even-collect]] §Key Findings.
- `send_push_to_users` was already safe under pytest (no-ops when
  `FIREBASE_CREDENTIALS_PATH` is unset) — only the Redis publish needed a
  seam.

## Root Cause
Three compounding facts: (1) the compose Redis intentionally has no host
port mapping; (2) `app/redis.py` defaults to `redis://localhost:6379`;
(3) the test suite had no seam between the realtime notify functions and
the real Redis client, so any test exercising a notifying write path
required live infra to pass.

## Prevention / Rule
**Guardrail:** `tests/conftest.py` now carries an autouse
`published_events` fixture that replaces `app.realtime._publish` with an
in-test recorder — no test may depend on a host-reachable Redis (or any
other live infra) to pass; the suite must stay green from a bare `pytest`
after `pip install -r requirements.txt`.

Recording (rather than discarding) the payloads turns the seam into an
assertion surface: tests verify the realtime contract (which event fires,
with what data) without a broker, the same way the existing SQLite
override verifies API contracts without Postgres.

## Solution

### Immediate Fix
Added to `tests/conftest.py` (mirroring the existing `get_db_session`
override pattern):
```python
@pytest_asyncio.fixture(scope="function", autouse=True)
async def published_events(monkeypatch):
    from app import realtime
    events = []
    async def _fake_publish(club_id, payload):
        events.append({"club_id": str(club_id), **payload})
    monkeypatch.setattr(realtime, "_publish", _fake_publish)
    return events
```
Result: `29 passed` (9 pre-existing incl. the 2 fixed, 20 new), stable
across repeat runs.

### Long-term Fix
- Add the CI job already recommended in
  [[CLUBZERO-2026-09-28-test-suite-could-not-even-collect]] (clean install
  + `pytest`, no infra services) — that job now also guards this seam:
  any new notify path that bypasses `realtime._publish` will fail there.
- If a test ever needs to verify actual broker delivery, scope it to an
  explicitly-marked integration test that spins up a throwaway Redis
  (per WORKING-PROCESS §5), not the default suite.

## Prevention
- [x] Hermetic publish seam in `tests/conftest.py`
- [ ] CI workflow running `pytest` from a clean install with no services
  (still open, see related entry)
- [ ] Documentation to update (`DEVLOG.md` §5 test-gap note can reference
  the new coverage)

## Related Issues
- [[CLUBZERO-2026-09-28-test-suite-could-not-even-collect]] — prior
  session's collection fix + local-Redis workaround this entry replaces
- Report: `reports/CLUBZERO-2026-09-28-pytest-coverage-habits-nudges.md`
  — the coverage initiative this fix unblocked

## References
- `club-zero-backend/tests/conftest.py`
- `club-zero-backend/app/realtime.py` (`_publish`, `notify_*`)
- `club-zero-backend/app/redis.py`
- `club-zero-backend/docker-compose.yml` (no Redis host port mapping)
- `SharedHQ/DEVLOG.md` §3 (Running the stack), §5 (test gap)

---

**Resolved By:** Muse Spark (opencode), same session as discovery, 2026-09-28
**Time to Resolution:** Same session as discovery
