# Malformed VerifiedHQ Database URL

**Date:** 2026-10-15
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The FastAPI database fallback URL and the development Docker Compose database URL
contained invalid leading characters, preventing the application from forming a
valid PostgreSQL connection string.

## Symptoms
- The backend could not reliably connect to PostgreSQL when `DATABASE_URL` was
  not explicitly supplied.
- The Compose backend environment pointed at a malformed database URL.

## Environment Details
- **Server/Host:** Local development and Docker Compose
- **Services Affected:** FastAPI backend, PostgreSQL connectivity
- **Related Components:** `backend/app/database.py`, `docker-compose.yml`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Read the database bootstrap and Compose service environment while preparing
backend verification.

### 2. Root Cause Analysis
The URL values began with `******`, which is not valid URI syntax and is not a
supported PostgreSQL driver prefix.

```bash
sed -n '1,80p' backend/app/database.py
grep -n 'DATABASE_URL' docker-compose.yml
```

### 3. Key Findings
- The expected async SQLAlchemy driver is `asyncpg`.
- The Compose PostgreSQL service uses `attendance_user`, `attendance_password`,
  database `attendance`, and service hostname `db`.
- The application default should target local PostgreSQL on `localhost`.

## Root Cause
Database connection strings were committed with malformed placeholder prefixes
instead of valid SQLAlchemy PostgreSQL URLs.

## Prevention / Rule
**Guardrail:** Validate `DATABASE_URL` at application startup with a Pydantic
settings model requiring the `postgresql+asyncpg://` scheme and reject any
placeholder characters.

This makes malformed configuration fail immediately with a descriptive error
instead of surfacing later as an opaque connection failure.

## Solution

### Immediate Fix
Use valid URLs:
- local fallback: `postgresql+asyncpg://attendance_user:attendance_password@localhost:5432/attendance`
- Compose backend: `postgresql+asyncpg://attendance_user:attendance_password@db:5432/attendance`

### Long-term Fix
Move credentials to validated environment/secrets configuration and add a
startup/readiness check to CI and Compose smoke tests.

## Prevention
- [x] Correct malformed URLs
- [ ] Add startup configuration validation
- [ ] Add Compose backend readiness smoke test
- [ ] Remove plaintext development credentials from shared deployment paths

## Related Issues
- None.

## References
- `backend/app/database.py`
- `docker-compose.yml`
- `docs/engineering_standards.md`
- `/home/shadowe/Projects/SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/5. Secure Application Configuration.md`

---

**Resolved By:** Copilot
**Time to Resolution:** Same review session
