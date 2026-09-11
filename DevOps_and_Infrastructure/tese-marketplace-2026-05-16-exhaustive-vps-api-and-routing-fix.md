# Exhaustive VPS API Connection and Routing Fix

**Date:** 2026-05-16
**Project:** Tese Marketplace
**Environment:** Production (VPS)
**Severity:** Critical
**Status:** Resolved

## Summary
Building on the previous fix attempt, it was discovered that multiple frontend services still contained hardcoded `localhost:8000` URLs and incorrect API paths. Additionally, the Nginx gateway was misconfigured to route the root path (`/`) to the backend instead of the frontend, preventing the SPA from loading its assets correctly.

## Symptoms
- `502 Bad Gateway` for static assets (JS/CSS/Images).
- `net::ERR_CONNECTION_REFUSED` for `/api/auth/login` and `/api/brain/ingest`.
- Browser console showing `localhost:8000` as the target for API calls despite being on a production domain.
- Chat/Messaging features failing with `404 Not Found` due to mismatched route paths.

## Environment Details
- **Server/Host:** 159.198.42.231 (VPS)
- **Services Affected:**
  - `customer-store` (Frontend)
  - `admin-dashboard` (Admin Frontend)
  - `api-gateway` (Nginx Orchestrator)
  - `chat-api` (Backend)
- **Time First Observed:** 2026-05-16 ~10:00 UTC

## Investigation Steps

### 1. Codebase Audit
A global search revealed multiple hardcoded `localhost:8000` strings in:
- `apps/admin-dashboard/src/lib/api.ts`
- `apps/admin-dashboard/src/services/productService.ts`
- `apps/customer-store/src/features/auth/services/authService.ts`
- `packages/common/src/analytics.ts`

### 2. Nginx Gateway Verification
Inspected `nginx/gateway.conf` and found:
```nginx
location / {
    proxy_pass http://tese-store-api:8000/;
}
```
This was incorrectly sending frontend requests to the backend store API.

### 3. Route Mapping Verification
- Frontend used `/messaging/conversations/`
- Backend (`chat-api/app/routes/chat.py`) used `@router.post("/conversations")`
- Path mismatch: `/api/messaging/` vs `/api/chat/`

## Root Cause
1. **Non-Exhaustive Fixes**: Previous fixes only updated `api.ts` but missed specialized services (image upload, analytics, chat) that implemented their own axios instances or hardcoded URLs.
2. **Gateway Misconfiguration**: The central orchestrator (Nginx) was not correctly separating frontend vs backend traffic at the root level.
3. **Mismatched Path Conventions**: Discrepancies between frontend service names (`messaging`) and backend service routes (`chat`).
4. **Build-Time Variable Omission**: Local deployment scripts and CI/CD workflows were inconsistent in passing `VITE_API_URL` during the `docker build` phase.

## Solution

### Immediate Fix
1. **Nginx Re-routing**: Updated `nginx/gateway.conf` to proxy `/` to `customer-frontend` and `/api/` to `store-api`.
2. **Relative Path Fallbacks**: Changed all hardcoded `localhost:8000` fallbacks to `/api` or `window.location.host`. This ensures the app is domain-agnostic.
3. **Exhaustive URL Cleanup**: Updated all service-level axios instances (Product Upload, Auth, Analytics) to use the standardized `BASE_URL`.
4. **Path Alignment**: Renamed `/messaging/` to `/chat/` in the frontend to match the backend API.

### Long-term Fix: Shipwright Implementation
Implemented **Shipwright** CI/CD tool to replace manual PowerShell scripts.
- **Mini-PaaS Mode**: Builds images directly on the VPS from source, ensuring environment variables are correctly injected during the build phase.
- **Automated Infrastructure**: Shipwright now manages Caddy/Proxy routing and Docker networks automatically.
- **Post-Deploy Hooks**: Automated database creation and seeding for all 8 microservices.

## Prevention
- [x] Standardize on relative paths (`/api`) for all frontend API calls.
- [x] Use a single source of truth for `BASE_URL` in each monorepo app.
- [x] Migrated to Shipwright for unified, environment-aware deployments.
- [x] Added `build-args` to `docker-compose.vps.yml` to ensure consistent builds across environments.

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 45 minutes
