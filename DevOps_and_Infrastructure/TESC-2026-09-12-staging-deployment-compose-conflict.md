# Staging Deployment Compose Conflict Causing 500 Errors

**Date:** 2026-09-12
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
A deployment to staging incorrectly used `docker-compose.staging.yml` instead of the main `docker-compose.yml`. This caused the `db` service to be recreated using a scratch volume (`tesc_postgres_data_staging`) rather than the active database volume, leaving the actual backend container (`tesc-backend-1`) orphaned without database access, leading to 500 Internal Server Errors on API calls like `/api/users/token/`.

## Symptoms
- The frontend returned a 500 Internal Server Error when trying to hit `/api/users/token/`.
- Logs for `tesc-backend-1` showed `django.db.utils.OperationalError: could not translate host name "db" to address: Temporary failure in name resolution`.

## Environment Details
- **Server/Host:** tesc-staging
- **Services Affected:** `tesc-backend-1`
- **Related Components:** PostgreSQL (`db`), Docker Compose networking
- **Time First Observed:** 2026-09-12T11:50:00+02:00

## Investigation Steps

### 1. Initial Diagnosis
Checked the docker containers running on the staging server using `docker ps`.

### 2. Root Cause Analysis
- Noticed that `tesc-backend-staging-v2` was running a dummy command `tail -f /dev/null`, and the actual API traffic was going to `tesc-backend-1`.
- Checked `docker-compose.staging.yml` and realized it defines a different volume `tesc_postgres_data_staging` and a dummy backend container.
- Concluded that executing `docker compose -f docker-compose.staging.yml up -d --build` recreated the `db` and `redis` services but connected them to the staging_net and empty volumes, detaching them from `tesc-backend-1`.

### 3. Key Findings
- The project relies on `docker-compose.yml` even on staging for actual container execution. `docker-compose.staging.yml` seems to be intended for isolated scratch testing but overrides the service names.

## Root Cause
Executing a deployment with the wrong compose file (`docker-compose.staging.yml`) which hijacked the `db` and `redis` service names but pointed them to empty volumes and a different network.

## Prevention / Rule
**Guardrail:** Delete or clearly rename the scratch compose file (e.g. `docker-compose.staging.SCRATCH-DO-NOT-USE.yml`) so it can't be invoked by muscle memory, and make a single wrapper script the only sanctioned deploy entrypoint — it resolves the correct compose file internally, so `-f <file>` is never hand-typed against a live environment.

The file that caused this outage wasn't malicious or even wrong on its own terms — it was a legitimate scratch config that happened to reuse real service names. The fix isn't "remember which file to use," it's removing the ability to pick the wrong one at all.

## Solution

### Immediate Fix
- Removed the dummy `tesc-backend-staging-v2` container.
- Re-ran the database and redis containers using the correct `docker-compose.yml` to reconnect them to the `postgres_data` volume on `main_net`.
- Ran a full rebuild `docker compose up -d --build backend celery-worker frontend-client-v2 frontend-admin-v2`.

```bash
docker compose up -d db redis
docker rm -f tesc-backend-staging-v2
docker compose up -d --build backend celery-worker frontend-client-v2 frontend-admin-v2
```

### Long-term Fix
Ensure deployments consistently refer to `project_docs/09-deployment-and-operations.md` instead of guessing which compose file to use. 

## Prevention
- [ ] Documentation to update: Clarify the exact usage of `docker-compose.staging.yml` versus `docker-compose.yml` in the runbooks.

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
