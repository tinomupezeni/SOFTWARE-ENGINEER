# Payments health failure returns HTTP 200

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** Development source review; runtime and production not exercised
**Severity:** Medium
**Status:** Investigating (local fix verified; deployment pending)

## Summary
The Payments service `/health` exception path returned `({"status": "unhealthy", "error": ...}, 500)`. FastAPI serializes this ordinary tuple as response content, so the route still returned HTTP 200 when the database query failed. Compose probes check HTTP status and could therefore report a failed database connection as healthy. The local source now returns an explicit HTTP 503 response.

## Symptoms
- Before the fix, the source failure path returned a tuple instead of an explicit HTTP error response.
- The development compose health check opens `/health` and accepts any successful HTTP status.
- Before the fix, a database failure could leave the Payments container marked healthy. This effect is inferred from source; it was not exercised in a running container.

## Environment Details
- **Server/Host:** Local source checkout at `/home/shadowe/Projects/HBEC`.
- **Services Affected:** Payments API and its Compose health probe.
- **Related Components:** `PAYMENTS/app/main.py`, `docker-compose.yml`.
- **Time First Observed:** 2026-11-07 source read-through.

## Investigation Steps

### 1. Initial Diagnosis
Read the Payments FastAPI entrypoint and Compose health check.

### 2. Root Cause Analysis
The exception handler treats a `(body, status)` tuple as if it set an HTTP status. FastAPI requires an explicit response status or `HTTPException` for that behavior.

```bash
sed -n '1,100p' PAYMENTS/app/main.py
sed -n '558,595p' docker-compose.yml
```

### 3. Key Findings
- The database probe is `SELECT 1`.
- On exception, the route returns the tuple directly.
- The health probe relies on the route's HTTP status.
- Local ASGI tests now assert 200 on success and 503 on a forced database exception.

## Root Cause
The failure branch uses a tuple return convention that FastAPI does not interpret as an HTTP status override.

## Prevention / Rule
**Guardrail:** Keep a Payments health test that forces the database call to fail and asserts the HTTP status is non-2xx, and run that test in CI. It directly checks the response contract the Compose probe uses.

## Solution

### Immediate Fix
`PAYMENTS/app/main.py` now logs the exception and returns `JSONResponse(status_code=503)` with a generic unhealthy body. `PAYMENTS/tests/test_api.py` verifies both success and database-failure HTTP responses using direct ASGI requests.

```bash
cd PAYMENTS
timeout 30s env PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 .venv/bin/python -m pytest -p pytest_asyncio.plugin tests/test_api.py -q -k health_check
# 2 passed, 6 deselected
```

### Long-term Fix
Align with the separate live and ready routes recorded in the related issue, then verify the deployed Compose probe in the target environment. The local HTTP behavior is verified; deployment has not occurred.

## Prevention
- [x] Add a negative database health test (local ASGI regression).
- [x] Implement an explicit non-2xx failure response.
- [ ] Verify the deployed health probe on the target environment.

## Related Issues
- `Backend_and_API/HBEC-2026-10-31-payments-notifications-missing-health-paths.md`

## References
- `PAYMENTS/app/main.py`
- `docker-compose.yml`
- HBEC `AGENTS.md`

---

**Resolved By:** Codex (local source fix; production pending)
**Time to Resolution:** Ongoing
