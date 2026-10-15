# Admin frontend origin missing from backend CORS configuration

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Environment:** Development  
**Severity:** High  
**Status:** Resolved

## Summary
The standalone admin frontend at `http://localhost:5174` could not call the Django API because the repository `.env` defined `CORS_EXTRA_ORIGINS` without the admin origin. The Compose fallback already listed port 5174, but the `.env` value took precedence.

## Symptoms
- Admin login failed in the browser.
- The browser reported that the preflight response had no `Access-Control-Allow-Origin` header.
- Direct API requests from the host worked, masking the browser-only integration failure.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Django backend and admin frontend
- **Related Components:** `backend/swapposell/settings.py`, `.env`, admin login
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Reproduced the browser preflight with an `OPTIONS` request from `http://localhost:5174`.

### 2. Root Cause Analysis
Inspected the running backend environment and found:

```text
CORS_EXTRA_ORIGINS=http://localhost:8080,http://127.0.0.1:8080
```

The `.env` value overrode the longer default in `docker-compose.yml`.

### 3. Key Findings
- The CORS middleware was installed and ordered correctly.
- The admin origin was absent from the running allowed-origin list.
- The failure affected preflight requests before the login view executed.

## Root Cause
The source-controlled environment configuration was not updated when the admin frontend's development port was introduced.

## Prevention / Rule
**Guardrail:** Every new browser-served frontend origin must be added to the canonical environment CORS list and verified with an `OPTIONS` preflight request before frontend integration is declared complete.

This prevents Compose defaults and checked-in environment overrides from drifting apart.

## Solution

### Immediate Fix
Added `http://localhost:5174` and `http://127.0.0.1:5174` to both the explicit Django allowed origins and `.env` `CORS_EXTRA_ORIGINS`.

### Long-term Fix
Add an automated smoke check for each configured frontend origin and move environment-specific origins into a clearly documented deployment configuration.

## Prevention
- [x] Configuration updated
- [x] Preflight verification added to validation
- [ ] Automated multi-origin smoke test

## References
- `backend/swaposell/settings.py`
- `.env`
- `docker-compose.yml`
- `admin/src/api.ts`

---

**Resolved By:** Copilot  
**Time to Resolution:** One investigation and rebuild cycle
