# Harness DB Password Drift Causing 502 Bad Gateway

**Date:** 2026-09-19
**Project:** HBEC
**Area:** Database and State

## Issue Description
The `harness-staging` API container was returning `502 Bad Gateway` on health checks and dashboard metrics endpoints. Logs showed it was stuck "Waiting for database...".

## Root Cause
- The `pgbouncer` container (and ultimately the `harness-db-staging` PostgreSQL database) was rejecting connections with `password authentication failed for user "harness"`.
- This occurred because a previous full staging recreation re-initialized the `.env` settings, but the existing Postgres persistent volume retained its old initialization password. The `harness` service was trying to connect using the new `.env` password, but the internal DB user still expected the old password.

## Resolution
- Ran an `ALTER ROLE harness WITH PASSWORD '...';` command directly inside the `hbec-harness-db-staging` container using `psql`, syncing the database's internal role password with the `.env` variable `HARNESS_DB_PASSWORD`.
- Restarted the `hbec-harness-staging` container. It immediately connected and ran Alembic migrations successfully.

**Resolved By:** Antigravity
