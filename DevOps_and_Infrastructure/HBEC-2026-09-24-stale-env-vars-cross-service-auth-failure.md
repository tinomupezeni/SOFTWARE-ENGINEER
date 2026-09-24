# Stale Environment Variables Causing Cross-Service Auth Failures

**Date:** 2026-09-24
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
Admin dashboard endpoints fetching from microservices (`/api/v1/content-gap-reports/outstanding-count` on the Notifications service and `/api/schools/institutions/` on the Schools service) were failing with `401 Unauthorized` and `403 Forbidden` respectively. The root cause was an incomplete deployment: the `.env` file had been recently updated with new secure secrets (`ADMIN_SECRET_KEY`, `SCHOOLS_ADMIN_SECRET`), but the microservice containers hadn't been recreated. The recently restarted `admin-backend` generated signatures using the new `.env` keys, while the target microservices rejected them because they were still verifying against the old development keys held in memory.

## Symptoms
- `GET /api/v1/content-gap-reports/outstanding-count` returned `401 Unauthorized`.
- `GET /api/schools/institutions/` returned `403 Forbidden`.
- The `schools-backend-staging` container logged `schools_admin_auth_failed: Invalid or missing admin signature`.
- The `notifications-backend-staging` container silently failed JWT verification in FastAPI security dependencies.

## Environment Details
- **Server/Host:** VPS (hbca-vps)
- **Services Affected:** `notifications-backend-staging`, `schools-backend-staging`
- **Related Components:** `admin-backend-staging`
- **Time First Observed:** 2026-09-24, after `admin-backend-staging` was independently recreated.

## Investigation Steps

### 1. Initial Diagnosis
- Investigated the `401` on the `notifications` endpoint and the `403` on the `schools` endpoint.
- Verified that the `admin-backend` token generation code correctly includes the required `role` claim, and that its HMAC signature logic matched `schools-backend`.

### 2. Root Cause Analysis
- Executed `printenv ADMIN_JWT_SECRET` inside `notifications-backend-staging` and found it was still using the default `django-insecure-dev-key...`.
- Executed `printenv SCHOOLS_ADMIN_SECRET` inside `schools-backend-staging` and found it was using `hbec-schools-admin-dev-key`.
- Compared these to the `.env` file on the host and the environment of the recently restarted `admin-backend-staging`, which were both using the new secure tokens (e.g., `xZ8vC...`, `ef036...`).
- Realized the microservices had simply not been restarted since the `.env` file was modified, causing a catastrophic desynchronization in shared cryptographic keys.

### 3. Key Findings
- Running `docker compose up -d <service>` or restarting a specific container leaves other containers untouched, even if their shared `.env` file has changed.
- If symmetric keys or shared secrets are changed in `.env`, a full environment recreation is strictly required.

## Root Cause
A partial deployment/restart led to the `admin-backend` container using newly updated cryptographic secrets from `.env`, while the `notifications` and `schools` microservices were still running with stale development secrets cached in their container environment variables. When `admin-backend` attempted to authenticate with these downstream services via JWT and HMAC, the signature verification failed.

## Prevention / Rule
**Guardrail:** When updating shared cryptographic secrets (JWT keys, HMAC secrets, database passwords) in a `.env` file, you must run a full cluster recreation (`docker compose up -d` without specifying individual services) rather than selectively recreating individual containers.

This ensures that all containers relying on symmetric keys are synchronized to the exact same version of the secret simultaneously, eliminating partial-update auth failures.

## Solution

### Immediate Fix
Forced a recreation of the trailing containers to synchronize their environment variables with the current `.env` file:
```bash
sudo docker compose -f docker-compose.staging.yml --profile workers up -d --force-recreate notifications schools-backend
```
Then ran internal `curl`/`urllib` checks from `admin-backend` to confirm both endpoints now returned `200 OK`.

### Long-term Fix
Ensure deployment documentation emphasizes cluster-wide restarts when mutating `.env` variables that govern cross-service communication.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update: Note the requirement for full cluster restarts on `.env` secret rotation.
- [ ] Code changes required

## Related Issues
- N/A

## References
- Docker Compose environment interpolation documentation.

---

**Resolved By:** Antigravity
**Time to Resolution:** ~15 minutes
