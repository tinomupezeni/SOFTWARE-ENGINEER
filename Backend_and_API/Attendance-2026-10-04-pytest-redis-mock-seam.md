# Backend pytest redis-mock seam broken (mocker.patch misses FastAPI dependency)

**Date:** 2026-10-04
**Project:** Attendance
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
Two of three backend tests fail without a live Redis because `mocker.patch("app.main.get_redis")` does not override the FastAPI dependency — requests still hit real Redis at `localhost:6379`. With a throwaway Redis running, one test still fails with an event-loop `RuntimeError`, so the seam is broken in both directions.

## Symptoms
- No Redis: `test_request_nonce_redis_mock`, `test_invalid_nonce_rejection` fail with `redis.exceptions.ConnectionError`.
- With disposable `redis:7-alpine`: 2 passed, `test_invalid_nonce_rejection` fails with `RuntimeError: Event ...` (loop mismatch between `AsyncMock` delete and real client lifecycle).

## Environment Details
- **Server/Host:** local dev, `backend/.venv`, `pytest tests/ -q`
- **Services Affected:** backend test suite only (production code untouched)
- **Related Components:** `backend/tests/test_api.py:13-16,24-29`, `backend/app/main.py` (`Depends(get_redis)`), `backend/app/redis_client.py:14` (`close()` deprecation)
- **Time First Observed:** 2026-10-04, while verifying Phase 0 admin changes

## Investigation Steps

### 1. Initial Diagnosis
Ran `pytest tests/ -q`: 2 failed, 1 passed, all on Redis connection.

### 2. Root Cause Analysis
Spun up throwaway Redis (`docker run --rm redis:7-alpine`): nonce test then passes, invalid-nonce test fails on event loop — proving the mock never actually replaced the dependency; the first test only passed because real Redis happened to be there.

### 3. Key Findings
- `mocker.patch` on the imported name does not affect FastAPI's `Depends(get_redis)` resolution; correct seam is `app.dependency_overrides[get_redis]`.
- Same broken-seam pattern already logged for CLUBZERO (`pytest-redis-test-seam`).
- Bonus: `redis_client.py:14` uses deprecated `close()` (should be `aclose()`).

## Root Cause
Tests mock the wrong seam: patching the module attribute instead of FastAPI's dependency-override map, so results depend on ambient infrastructure rather than the mock.

## Prevention / Rule
**Guardrail:** Backend test standard — all FastAPI dependency mocks must go through `app.dependency_overrides`, and CI must run the suite with no ambient Redis/Postgres (or with throwaway containers) so a test can only pass via its declared fixtures.

This closes the gap directly: the root cause is a mock that silently no-ops while ambient infra decides the outcome; forcing the override seam plus infra-independent CI makes that impossible.

## Solution

### Immediate Fix
Not applied (out of Phase 0 admin scope). Rewrite the two tests with `app.dependency_overrides[get_redis] = lambda: FakeRedis()`; replace `close()` with `aclose()`.

### Long-term Fix
CI job running backend pytest against throwaway Redis/Postgres per WORKING-PROCESS §5.

## Prevention
- [ ] Configuration changes needed: CI service containers for tests
- [ ] Monitoring/alerts to add: none
- [ ] Documentation to update: none
- [ ] Code changes required: fix test seam + `aclose()`

## Related Issues
- `CLUBZERO-2026-09-28-pytest-redis-test-seam` (same pattern, different project)

## References
- `backend/tests/test_api.py`
- `backend/app/redis_client.py`

---

**Resolved By:** N/A (flagged, not yet fixed)
**Time to Resolution:** N/A
