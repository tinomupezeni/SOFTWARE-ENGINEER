# API Path Mismatch and Fetch Client Bypass in Intelligence Studio

**Date:** 2026-10-09
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The Data Intelligence Studio frontend page encountered a 404 error when attempting to fetch report schemas. This occurred because the page used hardcoded raw `fetch` calls pointing to an incorrect API path, bypassing the centralized Axios `apiClient` used throughout the application.

## Symptoms
- The Data Intelligence Studio page failed to load report schemas.
- A 404 Not Found error was logged in the browser console for requests to `https://tesc-staging.zchpc.ac.zw/api/reports/builder/schema/`.
- 502 Bad Gateway errors or general API failures when tokens expired, due to the lack of automatic token refresh.

## Environment Details
- **Server/Host:** tesc-staging (`10.50.1.37`)
- **Services Affected:** `frontend-client-v2`
- **Related Components:** DataIntelligenceStudio.tsx, Django backend `reports` app
- **Time First Observed:** 2026-10-09

## Investigation Steps

### 1. Initial Diagnosis
Checked the frontend code for `DataIntelligenceStudio.tsx` to identify how API calls were structured. Noticed the use of raw `fetch` instead of `apiClient`.

### 2. Root Cause Analysis
- Verified the Django backend routes in `core/urls.py` and found `path("api/v1/reports/", include("reports.urls"))`.
- The frontend was making requests to `/api/reports/builder/schema/`, missing the `/v1/` versioning prefix.
- Investigated `frontend/src/services/api.ts` to see how other parts of the application communicate with the backend, identifying the centralized `apiClient` instance configured with the correct base URL and interceptors.

### 3. Key Findings
- The Intelligence Studio page bypassed standard API practices by using raw `fetch`.
- Bypassing the standard `apiClient` meant missing out on request/response interceptors (like token attachment and auto-refresh mechanisms) and error handling.
- The path mapping on the frontend was missing the `/v1/` portion of the path.

## Root Cause
A divergence from architectural standards in frontend API communication, where raw `fetch` was used with a hardcoded, outdated path structure, instead of using the globally configured `apiClient` and its base URL mapping.

## Prevention / Rule
**Guardrail:** Enforce a linting rule (e.g., ESLint rule `no-restricted-globals`) that prohibits the use of the global `fetch` API across the React frontend, ensuring all network requests utilize the centralized Axios `apiClient`.

This guardrail ensures that all network requests automatically inherit the correct base URL routing, authentication interceptors, and standardized error handling, preventing rogue endpoint paths and authentication bypass issues.

## Solution

### Immediate Fix
Replaced raw `fetch` requests with `apiClient` in `frontend/src/pages/DataIntelligenceStudio.tsx` and corrected the URL paths to include the `/v1/` prefix.

### Long-term Fix
Implement linting rules prohibiting `fetch` usage globally.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- None

## References
- None

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
