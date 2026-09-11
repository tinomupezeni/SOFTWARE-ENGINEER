# Production Routing, Google Auth, and Console Cleanup Resolution

**Date:** 2026-05-31
**Project:** HBEC
**Environment:** Production (VPS)
**Severity:** High
**Status:** Resolved

## Summary
Resolved multiple production issues affecting the HBEC Student Portal: persistent 404 errors on critical API endpoints, missing Google Sign-In functionality due to CSP blocks and build-time configuration failures, and excessive noise in the browser console from offline database initialization.

## Symptoms
- **404 Not Found:** GET /api/curriculum/levels/ failing on production despite being healthy on localhost.
- **Missing UI:** Google Sign-In button not appearing on Login/Signup pages.
- **CSP Errors:** Browser blocking ccounts.google.com scripts.
- **Console Spam:** Frequent Catalog Error: Table with name _schema_version does not exist! and Buffering missing file logs.

## Environment Details
- **Server/Host:** student.hbca.tech
- **Services Affected:** Student Frontend (Nginx/React), Student Backend (Django), Caddy (Host Proxy)
- **Time First Observed:** 2026-05-31

## Investigation Steps

### 1. Initial Diagnosis
Verified container health and backend responses via SSH. Confirmed backend returns 200 OK for /api/curriculum/levels/ when called directly.

### 2. Root Cause Analysis
- **Routing:** Caddy was using handle_path /api/*, which stripped the prefix before passing to Nginx, breaking Django's URL matching.
- **Build Args:** Docker Compose was not passing .env variables to the Docker builder, leaving VITE_GOOGLE_CLIENT_ID empty in the production JS bundle.
- **CSP:** Nginx security headers lacked the necessary overrides for Google's identity services.
- **DuckDB:** The schema check was executing a version query before verifying table existence, causing log-level noise.

## Solution

### Immediate Fix
- **Caddy:** Switched handle_path to handle in hbec.caddy to preserve full request URIs.
- **Docker:** Added rgs mapping to docker-compose.yml for VITE_GOOGLE_CLIENT_ID.
- **Nginx:** Updated CSP headers in 
ginx.conf to allow ccounts.google.com and lh3.googleusercontent.com.
- **Code:** Hardened schema.ts with a nested try-catch and pre-query table existence check using information_schema.

### Long-term Fix
Standardize the use of build arguments in Docker Compose for all VITE_ prefixed variables and maintain a "Proxy-Aware" Nginx configuration that preserves prefixes.

## Prevention
- [x] Fixed Caddy routing directives
- [x] Mapped build-time environment variables in Compose
- [x] Updated CSP to support external auth providers
- [x] Hardened frontend database initialization logic

## References
- Caddy documentation (handle vs handle_path)
- Vite Environment Variable guide
- DuckDB-WASM Catalog documentation

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 120 minutes
