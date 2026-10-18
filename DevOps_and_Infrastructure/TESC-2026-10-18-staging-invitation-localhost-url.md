# Staging Invitation Used a Localhost Portal URL

**Date:** 2026-10-18
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
Main-portal invitation emails generated on staging used `http://localhost:8081`
because the staging environment did not define `FRONTEND_URL`. Django therefore
loaded the development fallback instead of the public staging portal.

## Symptoms
- Newly created main-portal users received an invitation link pointing to localhost.
- The backend runtime reported `FRONTEND_URL=http://localhost:8081`.
- The invitation task accepted the incorrect URL from settings.

## Environment Details
- **Server/Host:** `10.50.1.37`
- **Services Affected:** `tesc-backend-1`, `tesc-celery_worker-1`
- **Related Components:** Django settings, Celery invitation task, staging `.env`
- **Time First Observed:** 2026-10-18

## Investigation Steps

### 1. Initial Diagnosis
The effective Django settings were inspected inside the staging backend before
recreation. `FRONTEND_URL` was `http://localhost:8081`, while the institution
portal URL was already configured for staging.

### 2. Root Cause Analysis
`backend/core/settings.py` used localhost as the fallback and staging
`/home/user/TESC/.env` did not define `FRONTEND_URL`. The invitation task uses
`settings.FRONTEND_URL`, so the missing environment value directly propagated
into email links.

### 3. Key Findings
- Staging had no explicit main-portal URL.
- The invitation worker and backend both consume the runtime setting.
- The staging rollback dump for the test account remained available and verified.

## Root Cause
The public frontend URL was treated as an implicit development default rather
than a required environment-specific deployment value.

## Prevention / Rule
**Guardrail:** Deployment validation must fail when a staging or production
runtime resolves a portal URL to localhost, loopback, or a staging-incompatible
host.

This catches both missing environment variables and unsafe source fallbacks
before invitation traffic is sent.

## Solution

### Immediate Fix
Added `FRONTEND_URL=https://tesc-staging.zchpc.ac.zw` to staging and recreated
the backend and active Celery worker. The source fallback now points to
`https://tesc.zchpc.ac.zw`, and the institution fallback points to
`https://tesc-inst.zchpc.ac.zw`.

### Long-term Fix
Keep portal URLs explicit in each deployment environment and add release-time
configuration parity checks for forbidden localhost and loopback values.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Main invitation sender/template and onboarding deployment records.

## References
- `backend/core/settings.py`
- `backend/users/tasks.py`
- Staging `/home/user/TESC/.env`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
