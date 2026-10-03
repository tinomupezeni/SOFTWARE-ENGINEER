# API 502 Bad Gateway due to Postgres Initialization Race Condition

**Date:** 2026-09-30
**Project:** CLUBZERO
**Environment:** Production (smepulse-vm)
**Severity:** High
**Status:** Resolved

## Summary
When deploying the Club Zero backend via Docker Compose, the Nginx reverse proxy reported a "502 Bad Gateway" error because the API container crashed shortly after starting. The API container crashed because it attempted to establish an asyncpg connection to the PostgreSQL database before the database had fully initialized and set its password, resulting in a `ConnectionRefusedError` and an `InvalidPasswordError`.

## Symptoms
- Attempting to access the backend via the reverse proxy domain (`https://smepulse.zchpc.ac.zw`) returned a 502 Bad Gateway error.
- Checking `docker ps -a` on the VM showed `club-zero-backend-api-1` as `Exited (3)`.

## Environment Details
- **Server/Host:** smepulse-vm (10.50.101.11)
- **Services Affected:** `club-zero-backend-api`
- **Related Components:** Nginx (reverse proxy), `docker-compose`, PostgreSQL 15.
- **Time First Observed:** 2026-09-30 19:54 (Local Time)

## Investigation Steps

### 1. Initial Diagnosis
- Verified VM IP addresses.
- Checked running containers using `docker ps`. The API container was notably missing/exited.

### 2. Root Cause Analysis
- Inspected the API container logs:
```bash
docker compose logs api
```
- Logs showed multiple errors from asyncpg during startup: `asyncpg.exceptions.InvalidPasswordError: password authentication failed for user "postgres"` followed eventually by `ConnectionRefusedError: [Errno 111] Connection refused`.

### 3. Key Findings
- The `api` container in `docker-compose.yml` had `depends_on: - db`, but `depends_on` only waits for the DB container to start, not for it to be fully ready to accept connections.
- The `postgres_data` volume may have had conflicting state from a previous container creation, contributing to the authentication error when the password wasn't set or updated properly in time.

## Root Cause
A race condition during Docker Compose startup: the FastAPI application attempted to initialize its SQLAlchemy async engine and execute database queries on startup before the PostgreSQL database container had fully initialized its tables and was ready to accept authenticated connections.

## Prevention / Rule
**Guardrail:** Use a healthcheck on the database container in `docker-compose.yml` and modify the API container's `depends_on` to wait for the `condition: service_healthy`.

This ensures that the API container is only started once `pg_isready` returns success inside the database container, guaranteeing that the database is fully initialized and ready to accept connections, closing the gap that causes the startup race condition crash.

## Solution

### Immediate Fix
Manually wiped the corrupted/conflicting database volume, restarted the docker compose stack, and then restarted the API container specifically after the DB had settled.

```bash
# Commands used to fix
docker compose down -v
docker compose up -d
docker compose start api
```

### Long-term Fix
Update `docker-compose.yml` to include a proper database health check and use `condition: service_healthy` for the API's `depends_on`. Additionally, configure `restart: always` or `restart: on-failure` for the API container so it can gracefully retry if a transient connection error occurs.

## Prevention
- [x] Configuration changes needed (Update docker-compose.yml with healthchecks)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None

## References
- None

---

**Resolved By:** Antigravity CLI
**Time to Resolution:** 10 minutes
