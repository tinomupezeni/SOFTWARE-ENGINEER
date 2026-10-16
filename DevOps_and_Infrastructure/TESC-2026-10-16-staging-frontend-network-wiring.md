# [TESC] Staging Institution Frontend Could Not Resolve Backend

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The institution frontend image was initially recreated using the generic
development Compose file, but its nginx configuration expected a `backend`
hostname that was unavailable on the container's network. Nginx exited before
serving the frontend.

## Symptoms
- `tesc-frontend-admin-v2-1` exited with nginx error:
  `host not found in upstream "backend"`.
- Port 8082 was not reachable after the image build.

## Root Cause
The staging Compose manifest did not define an institution frontend service,
and the generic Compose network did not contain the staging backend service
under the hostname expected by the frontend nginx configuration.

## Prevention / Rule
**Guardrail:** Every deployed frontend must be declared in the same environment
Compose manifest as its API backend, with an explicit shared network and
service alias for every nginx upstream.

## Solution
- Added `frontend-admin-staging` to `docker-compose.staging.yml`.
- Added the `backend` network alias to `tesc-backend-staging-v2`.
- Removed the failed generic-compose frontend container.
- Rebuilt and started the staging frontend from the institution source.

## Verification
- `curl http://127.0.0.1:8082/` returned HTTP 200.
- Backend and Celery worker remained healthy.
- Staging migration check returned successfully.

---

**Resolved By:** Copilot
**Time to Resolution:** Same staging deployment session
