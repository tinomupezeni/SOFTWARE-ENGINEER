# Production Frontend Bundle Could Use Localhost API

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Local production build; live deployment not inspected
**Severity:** High
**Status:** Resolved in deployed release 34274f0

## Summary
The tracked frontend `.env` points to `http://localhost:5001` and there was no production environment override. A standalone production build could bake a visitor-local API URL into its JavaScript.

## Symptoms
- A browser outside the host could send API requests to its own localhost instead of the Market-Link backend.
- This class of issue was previously recorded in the September 2026 login failure entry.

## Environment Details
- **Server/Host:** Local checkout; deployed bundle not inspected
- **Services Affected:** React frontend and API calls
- **Related Components:** `frontend/.env`, `frontend/.env.production`, `frontend/src/services/api.ts`
- **Time First Observed:** 2026-11-03 code investigation

## Investigation Steps

### 1. Initial Diagnosis
Compared the tracked frontend environment file with API URL construction and the documented reverse proxy route.

### 2. Root Cause Analysis
The development URL was available to production builds because no production-specific environment file overrode it.

```bash
rg -n 'REACT_APP_API_URL' frontend/.env frontend/.env.example frontend/src/services/api.ts
```

### 3. Key Findings
- The tracked `.env` specifies localhost.
- Public production routing is same-origin `/api`.
- The final local production bundle was checked for the localhost API string.

## Root Cause
Development API configuration was not separated from the production build configuration.

## Prevention / Rule
**Guardrail:** Require a production bundle check that rejects localhost and loopback API addresses in compiled JavaScript.

This catches environment drift before artifact promotion.

## Solution

### Immediate Fix
Added `frontend/.env.production` with `REACT_APP_API_URL=/api` and normalized the API base URL. Docker Compose also explicitly sets `/api`.

### Long-term Fix
Use a production build gate that scans the final artifact and run a live API journey after deployment.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `Frontend_and_UI/Market-Link-2026-09-20-frontend-login-failure-localhost-api.md`

## References
- `frontend/.env.production`
- `frontend/src/services/api.ts`
- `docker-compose.yml`

---

**Resolved By:** Codex (local code)
**Time to Resolution:** Same work session; deployment pending

## Verification

- `npm run build` succeeded.
- The compiled main JavaScript contained no `http://localhost:5001` string.
- Production deployment and browser smoke verification have not been performed.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
