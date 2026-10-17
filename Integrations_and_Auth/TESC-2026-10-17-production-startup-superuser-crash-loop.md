# Production startup superuser crash loop

**Date:** 2026-10-17
**Project:** TESC
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
The production backend entered a restart loop after image promotion because
startup checked for an existing superuser by email only, then attempted to
create username `admin` even though that username already existed with a
different email.

## Symptoms
- `tesc-main-backend-1` repeatedly restarted after the deployment.
- Public API traffic could not connect to port 8000.
- Logs reported `IntegrityError` on the unique `users_customuser_username_key`
  constraint for username `admin`.

## Environment Details
- **Server/Host:** Production VM `10.50.200.35`
- **Services Affected:** Django backend and nginx-proxied API
- **Related Components:** `backend/startup.sh`, CustomUser uniqueness
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Inspected container status and backend logs after the promoted image was
recreated.

### 2. Root Cause Analysis
The startup script used only
`User.objects.filter(email="admin@tesc.ac.zw").exists()` as its guard. The
production database already contained username `admin`, but not that exact
email, so `create_superuser(..., username="admin")` violated the username
unique constraint.

### 3. Key Findings
- Database migrations completed successfully before the crash.
- Celery and frontend containers remained running.
- The crash was deterministic on every backend restart.

## Root Cause
The bootstrap identity guard did not check all unique identity fields used by
the create operation.

## Prevention / Rule
**Guardrail:** Idempotent bootstrap scripts must check every uniqueness key
used by their create operation before inserting seed identities.

Checking both username and email prevents an existing production identity from
causing a startup failure when its attributes differ from development defaults.

## Solution

### Immediate Fix
Changed `backend/startup.sh` to create the seed superuser only when neither
the configured username nor email exists.

### Long-term Fix
Keep startup bootstrap operations idempotent and add a container-start smoke
test using a database containing legacy seed identities.

## Verification
The fix was rebuilt and deployed in TESC commit `13b5ebc`. Production logs
showed `Superuser already exists` followed by Gunicorn startup. The backend,
Celery worker, frontends, nginx, database, and Redis all remained running with
restart count zero. Public frontends returned HTTP 200, API routing returned
the expected Django HTTP 404 at `/api/`, and direct invalid bulk commit calls
raised validation errors instead of reaching the old duplicate or missing-key
failure paths.

## References
- `backend/startup.sh`
- Production backend logs
- TESC production deployment session

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
