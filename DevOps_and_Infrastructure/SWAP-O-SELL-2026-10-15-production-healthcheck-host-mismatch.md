# Production healthcheck rejected by Django host validation

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** VPS production deployment
**Severity:** Medium
**Status:** Resolved

## Summary
The first isolated VPS deployment built successfully, but Docker marked the Django backend unhealthy because its healthcheck requested `localhost` while production `ALLOWED_HOSTS` only contained the public domain.

## Symptoms
- Backend migrations and Gunicorn startup completed successfully.
- The backend healthcheck returned HTTP 400.
- Compose did not start dependent frontend and admin services during the first attempt.

## Environment Details
- **Server/Host:** `restk-vps`
- **Services Affected:** `swaposell-backend`
- **Related Components:** `docker-compose.production.yml`, `deploy/deploy.sh`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the backend container logs and Docker health state after Compose reported an unhealthy dependency.

### 2. Root Cause Analysis
The application was healthy and listening on port 8000, but Django rejected the healthcheck request with HTTP 400 because the request host was `localhost` and production `DJANGO_ALLOWED_HOSTS` contained only `swaposell.restksolutions.co.zw`.

### 3. Key Findings
- Database migrations completed without errors.
- Gunicorn started all workers successfully.
- The healthcheck itself lacked the public host header.
- The deploy script repeated the same invalid localhost-host probe.

## Root Cause
The production health probes did not use a host accepted by Django's host validation.

## Prevention / Rule
**Guardrail:** Production HTTP healthchecks must send an explicit accepted `Host` header whenever `ALLOWED_HOSTS` is restricted to public proxy domains.

This keeps health validation aligned with the application security boundary instead of weakening `ALLOWED_HOSTS` solely for internal probes.

## Solution

### Immediate Fix
- Updated the Compose healthcheck to send `Host: swaposell.restksolutions.co.zw`.
- Updated `deploy/deploy.sh` to use the same host header.
- Redeployed successfully; the backend became healthy and dependent services started.

### Long-term Fix
Keep healthcheck host values and production host configuration together in deployment configuration review.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None

## References
- `docker-compose.production.yml`
- `deploy/deploy.sh`
- VPS container `swaposell-backend-1`

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
