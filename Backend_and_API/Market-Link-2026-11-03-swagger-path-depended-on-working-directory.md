# Swagger Document Path Depended on Process Working Directory

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** VM and local merge
**Severity:** Low
**Status:** Resolved in deployed release 34274f0

## Summary
The VM's Swagger setup loaded `./swagger.yaml`, which resolves from the process working directory. Starting the backend from a directory other than `backend` could fail to load the document.

## Symptoms
- Server startup could fail if launched outside the backend directory.

## Environment Details
- **Server/Host:** `agromarket-vm`; local checkout
- **Services Affected:** Backend startup and API documentation
- **Related Components:** `backend/server.js`, `backend/swagger.yaml`
- **Time First Observed:** 2026-11-03 merge conflict review

## Investigation Steps

### 1. Initial Diagnosis
Reviewed both sides of the `backend/server.js` merge conflict.

### 2. Root Cause Analysis
The VM used a relative path; the local branch used `path.join(__dirname, 'swagger.yaml')`.

### 3. Key Findings
- Docker's current working directory may mask this issue.
- The path based on `__dirname` resolves beside `server.js` regardless of launch directory.

## Root Cause
The Swagger file path was tied to the caller's current working directory.

## Prevention / Rule
**Guardrail:** Resolve application assets relative to their module location.

This makes startup consistent across Docker, service managers, and direct Node execution.

## Solution

### Immediate Fix
Kept the module-relative `swagger.yaml` path when merging the VM commit. Preserved the VM Swagger document and dependencies.

### Long-term Fix
Add a startup check from an alternate current working directory if the launch mechanism changes.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `DevOps_and_Infrastructure/Market-Link-2026-10-06-vm-uncommitted-production-hotfixes.md`

## References
- `backend/server.js`
- `backend/swagger.yaml`

---

**Resolved By:** Codex
**Time to Resolution:** Same work session

## Verification

- Backend test suite passed with merged Swagger setup and installed dependencies.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
