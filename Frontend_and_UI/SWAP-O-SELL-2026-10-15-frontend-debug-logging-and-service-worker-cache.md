# Frontend debug logging and service-worker cache errors

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The storefront emitted verbose debug logs containing user, product, authentication, and access-token data. Its service worker also attempted to precache legacy asset paths that do not exist in the Vite build, causing an install-time cache error.

## Symptoms
- User and product payloads appeared repeatedly in the browser console.
- The access token was printed by the API request interceptor.
- Service-worker registration produced an `addAll` cache failure.

## Environment Details
- **Server/Host:** Local Vite/Docker storefront
- **Services Affected:** React storefront and service worker
- **Related Components:** `src/server/Server.tsx`, `src/server/api.tsx`, `src/components`, `src/pages`, `public/sw.js`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Searched the storefront source and service-worker files for console output and reviewed the service worker's precache list.

### 2. Root Cause Analysis
Debug statements remained across authentication, navigation, product cards, comments, messaging, and page actions. The service worker retained Create React App-style `/static/js/bundle.js` and `/static/css/main.css` paths although the application is built with Vite.

### 3. Key Findings
- The API interceptor exposed the full JWT in a console log.
- Several components logged complete user and product objects.
- The service-worker cache list contained files absent from the deployed frontend.

## Root Cause
Debug instrumentation was left in production-facing frontend paths, and the service worker's precache configuration was not updated when the frontend build system changed to Vite.

## Prevention / Rule
**Guardrail:** Add a production frontend check that fails when `console.log`, `console.debug`, or `console.info` remains in application source, and validate every service-worker precache URL against the built asset output.

This prevents sensitive debug output from shipping and catches stale cache manifests before service-worker installation fails.

## Solution

### Immediate Fix
- Removed active debug logs from the storefront source, including the access-token log.
- Removed duplicate inline service-worker registration.
- Removed nonexistent legacy static asset paths from the service-worker precache list.

### Long-term Fix
Keep error reporting focused on actionable failures without logging credentials or complete API payloads. Revisit service-worker caching when adding hashed build assets.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `SWAP-O-SELL-2026-10-15-mobile-navbar-duplicate-user-actions.md`

## References
- `swappify-social-hub/src/server/api.tsx`
- `swappify-social-hub/src/server/Server.tsx`
- `swappify-social-hub/public/sw.js`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
