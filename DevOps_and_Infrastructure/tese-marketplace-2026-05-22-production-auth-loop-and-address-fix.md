# Production Fix: Auth Loop (401) and Missing Addresses (404)

**Date:** 2026-05-22
**Project:** Tese Marketplace
**Environment:** Production (VPS)
**Severity:** Critical
**Status:** Resolved

## Summary
Immediately following the resolution of the Catalog API crash loop, users reported a "Login Loop" where logging in successfully would immediately redirect them back to the login page. Additionally, the Profile page was failing to load delivery addresses with a 404 error.

## Symptoms
- **Auth Loop:** Frontend console showed `401 Unauthorized` on `/api/orders` immediately after login. Frontend logic detected the 401 and forced a logout.
- **Missing Addresses:** `GET /api/addresses` returned `404 Not Found`.
- **Orchestrator Logs:** `Invalid JWT in Orchestrator: Signature verification failed`.

## Root Cause
1. **JWT Secret Mismatch:** The `store-api` Orchestrator was not receiving the `JWT_SECRET_KEY` in its environment. It was using a default dev secret to verify production tokens signed by the `auth-api`, leading to signature verification failures.
2. **Missing Feature Extraction:** The `/api/addresses` functionality had not yet been implemented in the newly extracted `order-api` microservice, and the Orchestrator lacked a routing entry for the "addresses" service name.

## Solution

### 1. Identity Verification Fix
- Injected `${JWT_SECRET}` into all microservices in `docker-compose.vps.yml` and `.shipwright.yml`.
- Verified that Orchestrator correctly forwards identity via `X-Tese-User-ID` headers to internal services.

### 2. Address Feature Implementation
- **Order API:** Implemented `Address` CRUD logic in the service layer and added REST endpoints (`/api/addresses`).
- **Orchestrator:** Updated the `SERVICE_MAP` to include `"addresses": f"{settings.ORDER_API_URL}/api/addresses"`.

### 3. Tooling Stability
- Fixed `ruff.toml` configuration to allow standardized Python linting across the monorepo.

## Prevention
- [x] Integrated **UATT Sentinel Contract Testing** to catch schema and routing mismatches during deployment.
- [x] Standardized `JWT_SECRET` injection across the entire Shipwright deployment manifest.

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 40 minutes
