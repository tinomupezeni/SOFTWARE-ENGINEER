# [TESC] Staging Endpoint Probe Target Mismatch

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** Medium
**Status:** Workaround Applied

## Summary
The endpoint smoke configuration targeted `http://localhost:8000`, but the active staging Compose backend did not publish port 8000 to the host. Host port 8000 served a different process and returned 404, while direct requests to the staging container IP were rejected by Django `ALLOWED_HOSTS` until an accepted `Host` header was supplied.

## Symptoms
- The smoke suite reported 404 for every API route at `localhost:8000`.
- Probing the backend container IP without a matching host returned Django `DisallowedHost` HTTP 400.
- The deployed staging backend itself responded correctly when contacted inside the container.

## Environment Details
- **Server/Host:** Local machine running `docker-compose.staging.yml`
- **Services Affected:** Staging API endpoint verification
- **Related Components:** `tests/.env.test.local`, `docker-compose.staging.yml`, Django `ALLOWED_HOSTS`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran `tests/01_smoke/test_smoke_api.py` with its configured `http://localhost:8000` target and observed uniform 404 responses.

### 2. Root Cause Analysis
Inspected Compose service publishing and container networking, then probed the backend from inside its container. The backend was healthy on container-local port 8000, but no host port was published. Probing its Docker IP also failed because the IP was not listed in `ALLOWED_HOSTS`.

```bash
docker compose -f docker-compose.staging.yml ps
docker exec tesc-backend-staging-v2 ...
```

### 3. Key Findings
- The active backend had no host port mapping.
- Host `localhost:8000` was not the staging backend.
- The backend accepted `Host: localhost` when reached through its container IP.
- The existing smoke configuration did not describe this deployment topology.

## Root Cause
The test target configuration assumed a host-published backend port that the staging Compose file did not provide, and the fallback direct container-IP probe did not account for Django host validation.

## Prevention / Rule
**Guardrail:** Add a preflight probe to the endpoint test runner that verifies the selected base URL returns the staging service identity and fails with an explicit target-mismatch message before running endpoint assertions.

This prevents an unrelated process or a `DisallowedHost` response from being recorded as dozens of application endpoint failures.

## Solution

### Immediate Fix
Ran the smoke checks against the staging backend container IP with `Host: localhost` and a freshly generated staging superuser token. All 34 existing GET smoke endpoints passed with HTTP 200.

### Long-term Fix
Choose one canonical staging access path: publish the backend port intentionally, provide a stable staging hostname, or make the test runner support the container network directly. Update `tests/.env.test.local` and the smoke runner to validate that path.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- None.

## References
- `tests/.env.test.local`
- `tests/01_smoke/test_smoke_api.py`
- `docker-compose.staging.yml`
- `backend/core/settings.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same verification session
