# ISSUE LOG: Deployed System Instability (400 Errors & Service Restarts)
**Date:** 2026-05-20
**Project:** Savens Blog
**Status:** RESOLVED (Live Fix + Architectural Patches)

## 1. Symptoms
- Frontend fetching `/blogs/` returned `400 Bad Request`.
- `savens-backend` logs showed `DisallowedHost` errors.
- `savens-rec` service in a restart loop (`NumPy X86_V2` error).
- `savens-analytics` service in a restart loop (`SettingsError` on `ALLOWED_HOSTS`).
- PWA Workbox errors: `non-precached-url: index.html`.

## 2. Root Cause Analysis

### A. Django Host Validation
Production domain `restkblog.restksolutions.co.zw` was missing from `ALLOWED_HOSTS`.

### B. Hardware Incompatibility (NumPy)
VPS QEMU CPU lacks `X86_V2` (SSE4.2). NumPy 1.26+ requires it.

### C. Pydantic-Settings List Parsing
`pydantic-settings` V2 attempts to parse `List[str]` environment variables as JSON by default. Comma-separated strings (e.g., `a,b,c`) fail this parsing logic before validators run.

### D. PWA Precache Missing Shell
`vite-plugin-pwa` was configured with `globPatterns: []`, causing the service worker to fail when attempting to serve `index.html` as the app shell.

## 3. Resolution Strategy

### Immediate Live Fix (VPS)
- Updated `infra/.env` with correct domains.
- Manually rebuilt and restarted services on VPS to bypass CI/CD health-check failures.

### Long-term Architectural Patches
- **Analytics Config:** Changed `ALLOWED_HOSTS` type from `List[str]` to `str` to ensure robust loading from environment strings.
- **Hardware Compatibility:** Downgraded NumPy to `1.24.4` for legacy CPU support.
- **PWA Fix:** Updated `vite.config.ts` to include essential shell files (`html`, `js`, `css`) in the precache manifest.
- **Compliance:** Updated deprecated Apple PWA meta tags in `index.html`.

## 4. Verification Results
- All services (`backend`, `frontend`, `rec`, `analytics`, `notifications`) are **UP and HEALTHY** on the VPS.
- Verified via `docker ps` and `docker logs`.

## 5. Lessons Learned
- **Bypass Complex Parsers:** For environment variables, favor simple types (`str`) and parse manually or via `SettingsConfigDict` if the framework's auto-parser is too rigid for production env formats.
- **Shell Preservation:** Always include the app shell (`index.html`) in PWA precache to avoid service worker boot-up crashes.
