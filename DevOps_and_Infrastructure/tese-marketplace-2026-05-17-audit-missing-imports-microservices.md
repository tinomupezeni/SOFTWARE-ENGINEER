# Multiple NameErrors: Missing Imports in Chat and Store APIs

**Date:** 2026-05-17
**Project:** Tese-Marketplace
**Environment:** Production (VPS) / Development
**Severity:** Critical
**Status:** Resolved (Fix applied)

## Summary
Audit of microservices revealed multiple instances of `NameError` due to missing imports. Specifically:
- `tese-store-api`: Missing `Depends`, `Session`, and `get_db`.
- `tese-chat-api`: Missing `asyncio` for startup tasks.

## Symptoms
- **Store API:** Crash on deep health check.
- **Chat API:** Crash on startup when trying to create Redis listener task.

## Environment Details
- **Services Affected:** tese-store-api, tese-chat-api
- **Related Components:** FastAPI, SQLAlchemy, asyncio

## Investigation Steps

### 1. Audit
Grep searched for all `deep_health` definitions and reviewed `startup_event` handlers.

### 2. Findings
Confirmed that `chat-api` was using `asyncio.create_task` without importing `asyncio`.

## Root Cause
Lack of standardized Python linting and testing across microservices. Developers are adding functionality (like deep health checks or background tasks) without verifying that all symbols are imported, and these errors are not caught until runtime because of a lack of static analysis in the CI/CD pipeline.

## Solution

### Immediate Fix
- Fixed `apps/store-api/app/main.py` by adding `Depends`, `Session`, and `get_db` imports.
- Fixed `apps/chat-api/app/main.py` by adding `asyncio` import.

### Long-term Fix
- [X] Audit all microservices (Completed).
- [ ] **Introduce `ruff` as a monorepo linter for Python.**
- [ ] Add a `lint` script to the root `package.json` that runs `ruff` on all Python apps.
- [ ] Update Dockerfiles or CI/CD to run linting before building/pushing.

## Prevention
Standardizing the Python environment and enforcing static analysis.

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 1 hour
