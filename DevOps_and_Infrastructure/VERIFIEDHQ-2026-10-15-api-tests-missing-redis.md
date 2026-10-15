# VerifiedHQ API Tests Missing Redis Service

**Date:** 2026-10-15
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
The backend API test suite requires Redis for nonce storage, but the local test
command does not provision or substitute a Redis service. As a result, endpoint
tests fail during infrastructure connection attempts before exercising their
assertions.

## Symptoms
- 13 API tests failed with `redis.exceptions.ConnectionError` to
  `localhost:6379`.
- Sensor-fusion tests passed independently.
- Docker Compose defines Redis, but the direct test command does not start it.

## Environment Details
- **Server/Host:** Local development
- **Services Affected:** Backend API tests, nonce/check-in endpoints
- **Related Components:** `backend/app/redis_client.py`, `docker-compose.yml`,
  `backend/tests/test_api_endpoints.py`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Ran the focused endpoint and sensor-fusion suites using the project `uv`
environment.

### 2. Root Cause Analysis
The endpoint tests use the production Redis dependency through FastAPI
dependency injection, while no Redis process is listening locally and no test
fake/override is configured.

### 3. Key Findings
- 31 sensor-fusion tests pass.
- Endpoint failures are connection/setup failures rather than behavior
  assertion failures.
- Compose configuration parses successfully and contains the required Redis
  service.

## Root Cause
Test infrastructure provisioning is separate from the test command and lacks a
deterministic Redis test substitute.

## Prevention / Rule
**Guardrail:** CI and documented local verification must run the API suite inside
the Compose test dependency set, or override Redis with a deterministic fake.

This prevents infrastructure availability from being confused with application
regressions.

## Solution

### Immediate Fix
Recorded the blocked verification state and preserved the passing unit-suite
result.

### Long-term Fix
Add a Redis dependency fixture or a test-only in-memory nonce store, then make
the API test command start all required services.

## Prevention
- [ ] Add Redis test fixture/override
- [ ] Add a documented Compose-backed API test command
- [ ] Separate unit and integration test markers
- [ ] Add CI service health checks

## References
- `backend/app/redis_client.py`
- `backend/tests/test_api_endpoints.py`
- `docker-compose.yml`

---

**Resolved By:** Copilot
**Time to Resolution:** Investigation complete; remediation deferred
