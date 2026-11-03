# VM Frontend Environment Sent Development Requests to Production

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** VM checkout and local merge
**Severity:** Medium
**Status:** Resolved in deployed release 34274f0

## Summary
The VM's tracked `frontend/.env` set `REACT_APP_API_URL` to the public production API. Merging that file directly would make local development requests reach the live service.

## Symptoms
- Development frontend requests would use the production domain after pulling the VM change.

## Environment Details
- **Server/Host:** `agromarket-vm`; local checkout
- **Services Affected:** Frontend development and production configuration
- **Related Components:** `frontend/.env`, `frontend/.env.production`, `docker-compose.yml`
- **Time First Observed:** 2026-11-03 merge review

## Investigation Steps

### 1. Initial Diagnosis
Compared the VM `.env` change with the local production override and Compose configuration.

### 2. Root Cause Analysis
The VM used one tracked `.env` file for deployment configuration. The local code now supplies a separate production override.

### 3. Key Findings
- The VM `.env` pointed at `https://agromarketing.co.zw/api`.
- Local development uses `http://localhost:5001`.
- Production builds and Compose use same-origin `/api`.

## Root Cause
Deployment-specific API origin was stored in the shared development environment file.

## Prevention / Rule
**Guardrail:** Keep environment-specific API origins in their respective build or deployment settings and check the compiled production bundle.

This prevents a development session from writing to production and prevents production from calling localhost.

## Solution

### Immediate Fix
During the merge, kept local `frontend/.env` on localhost and retained `frontend/.env.production` plus Compose's `/api` setting. The VM's other changes were preserved.

### Long-term Fix
Run build artifact and development API-origin checks before release.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `Frontend_and_UI/Market-Link-2026-11-03-production-bundle-localhost-api-default.md`

## References
- `frontend/.env`
- `frontend/.env.production`
- `docker-compose.yml`

---

**Resolved By:** Codex
**Time to Resolution:** Same work session

## Verification

- Frontend tests passed and production build succeeded after merge resolution.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
