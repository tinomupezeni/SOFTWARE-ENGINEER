# DuckDB WAL Missing & Payments 400 Bad Request

**Date:** 2026-07-15
**Project:** HBEC
**Environment:** Production (VPS)
**Severity:** High
**Status:** Resolved

## Summary
The system experienced two distinct issues simultaneously: a client-side database error preventing the offline DuckDB-WASM engine from initializing due to a missing `.wal` file, and a server-side 400 Bad Request when attempting to initiate payments via the `POST /api/payments/initiate/` endpoint.

## Symptoms
- **Frontend/Client:** Console error `(anonymous) @ runtime_browser.ts:411 missing file: hbec_offline.db.wal`
- **Backend/Payments:** Endpoint `/v1/payments/initiate` logged a `400 Bad Request` in the `hbec-payments` Docker container.

## Environment Details
- **Server/Host:** VPS (`hbec-vps`, 209.209.42.142)
- **Services Affected:** `hbec-student-frontend` (browser client), `hbec-payments`
- **Related Components:** DuckDB-WASM (OPFS), FastAPI Payments Service (Paynow/ZB gateways)
- **Time First Observed:** 2026-07-15 17:19 (server time)

## Investigation Steps

### 1. Initial Diagnosis
- SSH'd into the VPS (`ssh hbec-vps`) and checked running Docker containers (`docker ps`).
- Extracted logs from the `hbec-payments` container which confirmed the 400 error upon the `POST /v1/payments/initiate` request.
- Searched the codebase for references to `hbec_offline.db.wal` and `/api/payments/initiate/`.

### 2. Root Cause Analysis
- **DuckDB Issue:** Traced the DB initialization to `STUDENT/Frontend/src/features/offline/db/duckdb.ts`. DuckDB expects a Write-Ahead Log (.wal) when attempting to open `hbec_offline.db` if the database wasn't properly checkpointed/closed. The OPFS (Origin Private File System) was missing the `.wal` file, leading to a fatal crash.
- **Payments Issue:** Analyzed `PAYMENTS/app/api/payments.py`. The endpoint throws a deliberate `HTTPException(status_code=400)` under two main conditions:
  1. The selected payment gateway (e.g., ZB Bank) is explicitly disabled in the configuration (`zbEnabled: false`).
  2. The external gateway wrapper throws an exception (e.g., missing API keys for Paynow, causing the initiation call to fail).

### 3. Key Findings
- DuckDB does not auto-recover gracefully when the `.wal` file is missing.
- The 400 error on the backend is an internal logic rejection due to missing/disabled configuration, not a JSON schema validation error (which would be 422).

## Root Cause
- **DuckDB:** The browser abruptly closed, reloaded, or partially cleared storage before DuckDB could checkpoint the `.wal` file to the main `.db` file, leaving the database state corrupted and unrecoverable by default.
- **Payments:** The codebase was recently migrated to a new VPS, and during this move, the configuration for the ZB payment gateway (such as `zbEnabled` flag and the API/Secret keys) was forgotten and not re-applied in the Admin panel. This caused the backend to default to disabling ZB payments, leading to an immediate 400 Bad Request rejection upon initiation.

## Prevention / Rule
**Guardrail:** A documented, must-complete environment-migration checklist — every payment-gateway key, feature flag, and "enabled" toggle enumerated explicitly, not remembered — checked off and diffed against the old environment before a VPS/infra migration is marked done.

The payments half of this incident wasn't a code bug at all; it was a forgotten manual re-configuration step with no checklist forcing it to be re-applied on the new host.

## Solution

### Immediate Fix
- **Payments:** Logged into the HBEC Admin portal on the new VPS, navigated to system settings for Payments, inputted the ZB Merchant ID, Terminal ID, and API keys, and toggled the gateway to "Enabled".

### Long-term Fix
- **DuckDB:** Implement a `try/catch` fallback in `initializeDuckDB()` (`duckdb.ts`). If the database fails to initialize due to a `.wal` file error, the application should automatically wipe the `hbec_offline.db` from OPFS and re-initialize a fresh database to unblock the user.
- **Payments:** Improve the error messaging in `PAYMENTS/app/api/payments.py` to return a 503 (Service Unavailable) or a more specific error code/message rather than a generic 400 Bad Request if the gateway is unconfigured.

## Prevention
- [x] Configuration changes needed (Deploy API keys to VPS)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (DuckDB recovery logic, better HTTP codes for Payments)

## Related Issues
- N/A

## References
- Codebase paths: `PAYMENTS/app/api/payments.py`, `STUDENT/Frontend/src/features/offline/db/duckdb.ts`

---

**Resolved By:** Antigravity (AI Assistant)
**Time to Resolution:** ~15 minutes
