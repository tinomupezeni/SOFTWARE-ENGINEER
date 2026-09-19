# Environment Drift on Staging Causes Admin Frontend Errors

**Date:** 2026-09-19
**Project:** HBEC
**Area:** DevOps and Infrastructure

## Issue Description
After merging PR #44 (which introduced changes to `docker-compose.staging.yml` for JWT secrets and HMAC keys), the Admin Frontend began throwing 401 Unauthorized, 403 Forbidden, and 502 Bad Gateway errors when accessing `/api/v1/content-gap-reports/outstanding-count`, `/schools/institutions/`, and `/api/agents/usage/summary/`.

## Root Cause
1. **Partial Deployment:** A previous deployment ran `docker compose up -d` targeting only specific services (e.g., `student-backend`, `admin-backend`, etc.), completely skipping the recreation of `harness`, `notifications-backend`, and `schools-backend`. This resulted in these containers running old configurations missing the `ADMIN_JWT_SECRET` and `REPLICATION_HMAC_KEY` bindings added in PR #44. Because of this missing configuration, authentication tokens and HMAC signatures between the microservices failed, producing the 401 and 403 errors.
2. **Database Password Sync:** `pgbouncer` was updated to use a new `HARNESS_DB_PASSWORD` from `.env`, but `harness-db` (PostgreSQL) was not updated. Since PostgreSQL only reads the initialization password on first boot, the internal database password remained stale. When `pgbouncer` attempted to connect to `harness-db`, it failed with "password authentication failed", causing `harness` to hang on startup (and resulting in 502 Bad Gateway from `admin-backend`).

## Resolution
- Ran a full `docker compose -f docker-compose.staging.yml up -d` without specifying services to ensure all containers were recreated with the latest configuration.
- Manually executed an `ALTER USER harness WITH PASSWORD '...';` command via `psql` inside the `harness-db` container to synchronize the database user's password with the `.env` value.

**Resolved By:** Antigravity
