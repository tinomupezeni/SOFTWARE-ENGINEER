# TESC Invitation URL Configuration

**Date:** 2026-10-18
**Project:** TESC
**Type:** Configuration Fix / Deployment Verification
**Status:** Completed

## Summary
Corrected the main-portal invitation URL configuration so staging invitations
point to the public staging portal rather than localhost, while the source
fallback is now production-safe for the main and institution portals.

## Context / Trigger
The latest staging invitation path still had `http://localhost:8081` as the
main portal URL. The user also requested the production main portal URL to be
`https://tesc.zchpc.ac.zw`.

## Scope
Included source defaults, staging runtime configuration, backend and worker
recreation, account-deletion verification, service health, and invitation
worker registration. Production data and production services were not changed.

## Method
Inspected effective settings inside the running containers, updated only the
staging environment and the central source defaults, recreated the services
that consume runtime configuration, and ran read-only smoke checks against both
public portals.

## Decisions & Findings
- Staging main URL is `https://tesc-staging.zchpc.ac.zw`.
- Staging institution URL remains `https://tesc-inst-staging.zchpc.ac.zw`.
- Source defaults are `https://tesc.zchpc.ac.zw` and
  `https://tesc-inst.zchpc.ac.zw`.
- The previously deleted staging test account has zero email and username
  matches.
- The controlled rollback dump remains present with SHA-256
  `92565b2db35e80a725bd6e1efc2c0e59644d16040473411651e92ef4cc681ac5`.

## Changes Made
- Updated `backend/core/settings.py` production-safe URL defaults.
- Added `FRONTEND_URL=https://tesc-staging.zchpc.ac.zw` to the staging `.env`.
- Recreated `tesc-backend-1` and `tesc-celery_worker-1`.

## Verification
- Django `check`: passed.
- Staging backend effective `FRONTEND_URL`: correct.
- Staging Celery worker effective `FRONTEND_URL`: correct.
- Invitation task registration: present.
- Main staging portal: HTTP 200.
- Institution staging portal: HTTP 200.
- Staging migrations: no pending migrations during deployment check.
- Deleted test account: no remaining email or username matches.

## Follow-ups / Deferred
- A real SMTP relay delivery with the new sender remains unverified because the
  prior direct SMTP authentication probe timed out.
- Production runtime configuration was not modified in this staging-scoped
  change; production should be verified separately before its next deployment.

## References
- `backend/core/settings.py`
- `backend/users/tasks.py`
- `DevOps_and_Infrastructure/TESC-2026-10-18-staging-invitation-localhost-url.md`

---

**Completed By:** Copilot
**Duration:** Same session
