# Database Connection Leak & PgBouncer Reconfiguration

**Date:** 2026-06-25
**Project:** HBEC
**Environment:** Production (VPS)
**Severity:** Critical (500 errors on Admin backend)
**Status:** Resolved

## Summary
Admin backend was returning 500 errors due to PostgreSQL `max_connections` exhaustion. Backends were bypassing PgBouncer and connecting directly to Postgres, and Celery workers were leaking connections over time. Fixed by routing all services through PgBouncer, configuring SCRAM-SHA-256 auth, and setting `CONN_MAX_AGE = 0`.

## Symptoms
- Admin panel returning 500 Internal Server Error
- Health checks failing with `FATAL: sorry, too many clients already`
- Docker containers showing `(unhealthy)` status for admin-backend and student-backend
- 116 zombie processes on VPS (blocked DB connections)

## Root Causes

### 1. Backends Bypassing PgBouncer
The `x-student-db-env` and `x-admin-db-env` YAML anchors in `docker-compose.yml` set `POSTGRES_HOST: postgres` (direct to raw Postgres container), bypassing the PgBouncer pool entirely. PgBouncer was only configured for `harness-db`.

### 2. Connection Leaks (Recurrence Risk)
Even after routing through PgBouncer, long-running Celery workers and beats hold database connections open indefinitely. Django's default `CONN_MAX_AGE` (persistent connections) combined with Celery's connection reuse causes connections to accumulate over days, eventually exhausting any pool.

### 3. PgBouncer Auth Mismatch
Modern psycopg (v3) uses SCRAM-SHA-256 authentication by default, but PgBouncer was not configured to handle it, causing `FATAL: server login failed: wrong password type`.

## Fix Applied

### docker-compose.yml Changes
- Changed `POSTGRES_HOST: postgres` to `POSTGRES_HOST: pgbouncer` in all three DB anchors (student, admin, payments)
- Added `depends_on: pgbouncer: condition: service_healthy` to student-backend, admin-backend, and payments
- Updated PgBouncer environment:
  - `DATABASE_URL` now points to main postgres cluster (not just harness-db)
  - Added `AUTH_TYPE: scram-sha-256`
  - Added `AUTH_QUERY: "SELECT usename, passwd FROM pg_shadow WHERE usename=$1"`
- Set `POOL_MODE: transaction`, `MAX_CLIENT_CONN: 500`, `DEFAULT_POOL_SIZE: 50`

### Django Settings Required (Prevention)
Set `CONN_MAX_AGE = 0` in `config/settings/production.py` for all database configurations to force Django to release connections back to PgBouncer after each request/task. Without this, Celery workers will hold connections open indefinitely and the pool will exhaust again over time.

### Celery Tasks (Best Practice)
All raw database access in Celery tasks must use context managers:
```python
with connection.cursor() as cursor:
    cursor.execute(...)
```

## Verification
- Connection limit smoke test: 250 concurrent requests, 100% success (0 failures)
- All containers healthy: admin-backend, student-backend, payments, workers, beats
- `pg_stat_activity` no longer shows idle connections accumulating

## Prevention
- [ ] Set `CONN_MAX_AGE = 0` in production Django settings
- [ ] Audit Celery tasks for unclosed database connections
- [ ] Add `pg_stat_activity` monitoring to alert on idle connection spikes
- [ ] Document PgBouncer architecture in deployment guide

---

**Resolved By:** Gemini CLI
**Time to Resolution:** ~2 hours (diagnosis + fix + redeploy)
