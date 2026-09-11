# VPS Service Interruption: Catalog API Crash Loop & Auth Failures

**Date:** 2026-05-22
**Project:** Tese Marketplace
**Environment:** Production (VPS)
**Severity:** Critical
**Status:** Resolved

## Summary
Users reported widespread failures when attempting to sign up, log in, or browse products on the production platform. Investigation revealed that the `catalog-api` microservice was stuck in a crash loop due to database connectivity failures, while the `auth-api` was returning validation errors (422) that were being misinterpreted as routing failures.

## Symptoms
- `404 Not Found` or `502 Bad Gateway` when fetching product listings.
- `422 Unprocessable Entity` on authentication requests (Login/Signup).
- Frontend showing empty product grids or "Failed to load listings" toasts.
- Catalog API logs showing `psycopg2.OperationalError: connection to server at "db" failed: Connection refused`.

## Environment Details
- **Server/Host:** 159.198.42.231 (VPS)
- **Services Affected:**
  - `catalog-api` (Crashed)
  - `auth-api` (Functional but returning errors)
  - `customer-store` (Frontend impact)
- **Time First Observed:** 2026-05-22 ~13:00 UTC

## Investigation Steps

### 1. Connectivity Audit
SSH'd into the VPS and checked container status. All containers were "Up", but `catalog-api` logs revealed it was crashing immediately after startup:
```python
sqlalchemy.exc.OperationalError: (psycopg2.OperationalError) connection to server at "db" (192.168.48.9), port 5432 failed: Connection refused
```

### 2. Auth Service Verification
Checked `auth-api` and `store-api` logs. Requests were reaching the Auth service correctly, but failing with `422` due to malformed JSON or missing fields in the registration payload.

### 3. Database Health Check
Verified the database container (`tese-db-legacy`) was healthy and accepting connections. Used `docker exec` to manually query the `users` table, which confirmed the DB was live but the Catalog API had failed to reconnect after a transient failure.

## Root Cause
1. **Transient DB Unavailability**: The database service likely had a brief moment of unresponsiveness or restart during which the `catalog-api` attempted to connect and failed.
2. **Lack of Resilient Reconnect**: The `catalog-api` startup logic (`init_db()`) lacked sufficient retry logic, causing the container to exit when the DB was unreachable.
3. **Mismatched Error Handling**: The frontend was reporting generic failures for Auth issues because the orchestrator was passing through `422` errors from Pydantic which were being treated as system failures by the client.

## Solution

### Immediate Fix
1. **Full Stack Restart**: Performed a `docker compose -f docker-compose.vps.yml restart`. This forced all services to re-establish connections to the database and Redis.
2. **Connectivity Validation**: Verified that `catalog-api` successfully initialized and `store-api` began correctly forwarding requests.
3. **Manual Verification**: Confirmed that `GET /api/catalog/products` now returns `200 OK` with data.

### Long-term Fix
1. **Database Wait-for-IT**: Updated deployment strategy to ensure the database is fully ready (accepting TCP connections) before backend services attempt to initialize.
2. **Enhanced Retry Logic**: (Planned) Implement exponential backoff for database connection attempts in the microservice base templates.

## Prevention
- [x] Implemented deep health checks (`/api/v1/health/deep`) across all services to monitor DB connectivity.
- [x] Standardized Docker `healthcheck` in `docker-compose.vps.yml` to prevent unhealthy services from being routed to by the gateway.
- [x] Added debug logging to the `store-api` orchestrator to trace request/response cycles in production.

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 30 minutes
