# Production Frontend Runs React Development Server

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Production VM
**Severity:** Medium
**Status:** Open; existing deployment design retained during functional release

## Summary
The production frontend Dockerfile starts `npm start`, which runs `react-scripts start`. The live container serves the development server and its full toolchain on port 3001.

## Symptoms
- Frontend startup compiles on the VM and initially times out while compiling.
- The runtime image contains development tooling and its reported dependency advisories.

## Environment Details
- **Server/Host:** `agromarket-vm`
- **Services Affected:** Public frontend
- **Related Components:** `frontend/Dockerfile`, `docker-compose.yml`
- **Time First Observed:** 2026-11-03 release inspection

## Investigation Steps

### 1. Initial Diagnosis
Inspected the running process and Dockerfile, then observed frontend startup during redeployment.

### 2. Root Cause Analysis
Dockerfile `CMD ["npm", "start"]` launches the React development server rather than serving a built production bundle.

### 3. Key Findings
- The new frontend passed tests and build checks; it returned HTTP 200 after startup compilation.
- This deployment design predates the current functional release.

## Root Cause
No static production frontend image or serving path is configured for Compose.

## Prevention / Rule
**Guardrail:** Run a production build during image creation and serve only compiled static assets in production.

This reduces startup latency and removes development tooling from the public runtime.

## Solution

### Immediate Fix
Documented the existing design; retained it to keep the requested functional redeployment scoped and reversible.

### Long-term Fix
Use a multi-stage frontend image and a static server, then test API proxying and rollout behavior.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `DevOps_and_Infrastructure/Market-Link-2026-11-03-frontend-runtime-dependency-advisories.md`

## References
- `frontend/Dockerfile`
- `docker-compose.yml`

---

**Resolved By:** Pending
**Time to Resolution:** Pending

## Verification

- `docker ps` and logs showed `react-scripts start` in the live frontend container.
