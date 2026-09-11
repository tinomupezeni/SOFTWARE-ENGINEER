# Monorepo VPS Deployment Failures and Resolution

**Date:** 2026-05-09
**Project:** Tese-Marketplace
**Environment:** Production (VPS)
**Severity:** High
**Status:** Resolved

## Summary
The migration from a standalone backend to a monorepo architecture encountered multiple failures during the initial VPS deployment using a new automated PowerShell script. These included build errors, authentication failures, database connectivity issues, and gateway misconfigurations.

## Symptoms
- Docker build failures due to outdated lockfiles.
- 502 Bad Gateway errors on all domains (tesemarket.com, admin.tesemarket.com).
- Critical services (store-api, auth-api) failing to start or connecting to the wrong databases.
- Frontend containers marked as 'unhealthy' in Docker.

## Environment Details
- **Server/Host:** VPS (159.198.42.231)
- **Services Affected:** All (auth-api, store-api, catalog-api, brain-api, chat-api, customer-store, admin-dashboard, api-gateway)
- **Related Components:** Caddy (Global Proxy), PostgreSQL (Legacy DB), Redis
- **Time First Observed:** 2026-05-09

## Investigation Steps

### 1. Initial Diagnosis
- Checked script output for build and push stages.
- Ran `docker compose ps` on the VPS to identify service health.
- Checked logs for the API Gateway and backend services.

### 2. Root Cause Analysis
- **Lockfile Mismatch:** Noticed the build failed because `playwright-lighthouse` was added to `package.json` but not updated in `pnpm-lock.yaml`.
- **Database Connectivity:** Services crashed with "could not translate host name '1234@db'". Realized the '@' in the password 'tese@1234' was breaking the `DATABASE_URL` parser in SQLAlchemy.
- **Missing Databases:** `tese_chat`, `tese_brain`, etc., were not automatically created by the script due to quoting issues in PowerShell over SSH.
- **Nginx Failures:** Gateway logs showed "invalid parameter '80'" due to extra spaces in `upstream` definitions and CRLF line ending issues in Alpine Linux.
- **Unhealthy Frontends:** Healthchecks failed because Nginx on Alpine/Docker sometimes struggles with `localhost` resolving to IPv6 inside the container.

### 3. Key Findings
- Password special characters require URL encoding for SQLAlchemy `DATABASE_URL`.
- PowerShell string interpolation and pipes require careful escaping when passed to SSH/Bash.
- Central proxy configurations must be manually aligned when container names change.

## Root Cause
The primary cause was a combination of environment variable parsing ambiguity (special characters in DB passwords), monorepo naming drift between the stack and the global proxy, and platform-specific behavior (line endings and localhost resolution).

## Solution

### Immediate Fix
- Updated `pnpm-lock.yaml` locally.
- URL-encoded the database password (`tese%401234`) in the backend connection strings.
- Manually created missing PostgreSQL databases on the VPS.
- Fixed `nginx.conf` upstream syntax and line endings (`sed -i 's/\r$//'`).
- Updated healthchecks to use `127.0.0.1`.
- Surgically updated the VPS **Central Caddyfile** to route to new container names.

### Long-term Fix
- Created a robust PowerShell deployment script (`tese.ps1`) that handles:
    - Automatic DB creation with proper escaping.
    - CRLF to LF conversion for config files.
    - Dynamic `.env` generation with URL-encoded variants of sensitive vars.
    - Central Caddy reload triggers.

## Prevention
- [x] Automated line ending normalization in the deploy script.
- [x] Use of `127.0.0.1` for container healthchecks.
- [x] Pre-deployment verification of database existence.
- [x] Documentation of the `DATABASE_PASSWORD_URL` requirement.

## References
- SQLAlchemy Connection String Docs
- Nginx Upstream Syntax

---

**Resolved By:** Gemini CLI (tinotenda762)
**Time to Resolution:** ~1.5 hours
