# Frontend deployed with loopback API URL

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The staging deployment replaced the previous static nginx frontend with a Vite development-server image whose frontend bundle resolved the API URL to `http://localhost:8000/api`. Production browsers therefore attempted to call their own loopback address, causing workspace, notification, and authentication requests to fail with loopback-address and CORS errors.

## Symptoms
- Browser requests targeted `http://localhost:8000/api/...`.
- Requests from `https://projectflow.thuthuka.tech` failed with `net::ERR_FAILED`.
- The browser reported permission denial for the loopback address space and missing CORS headers.
- Backend and database services remained healthy.

## Environment Details
- **Server/Host:** `restk-vps`
- **Services Affected:** ProjectFlow frontend
- **Related Components:** `projectflow-hq/Dockerfile`, `projectflow-hq/src/lib/constants.ts`, `deploy.sh`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the frontend source, Dockerfile, deployed image command, and served Vite module.

### 2. Root Cause Analysis
`deploy.sh` passed `--build-arg VITE_API_URL=...`, but the frontend Dockerfile did not declare or export that argument. The fallback in `src/lib/constants.ts` therefore remained `http://localhost:8000/api`. The Dockerfile also ran the Vite development server rather than the prior nginx/static frontend image.

```bash
grep -RIn 'VITE_API_URL\|localhost:8000' projectflow-hq/src projectflow-hq/Dockerfile
docker inspect projectflow-frontend-1
curl http://127.0.0.1:18080/src/lib/constants.ts
```

### 3. Key Findings
- The deployed broken frontend used `projectflow-frontend:latest` from the local `Dockerfile`.
- The build argument was ignored because no `ARG VITE_API_URL` existed.
- The previous working image was `sha256:e8c6707813691896636530a74a84fced5337effe9fd82459ce4cfc34f10ef341` and used nginx.

## Root Cause
The backend deployment script referenced a frontend Dockerfile whose runtime/build contract did not support the API URL argument.

## Prevention / Rule
**Guardrail:** Require a frontend image smoke test in deployment that fetches the served application module or built asset and fails if it contains `localhost:8000` or lacks the configured public API origin.

This directly catches loopback API URLs before the image is uploaded or promoted.

## Solution

### Immediate Fix
Rolled back only the frontend container to image `sha256:e8c6707813691896636530a74a84fced5337effe9fd82459ce4cfc34f10ef341`. Backend, scheduler, database, migrations, and observability remained untouched.

### Long-term Fix
Added `ARG VITE_API_URL=/api` and `ENV VITE_API_URL=$VITE_API_URL` to the frontend Dockerfile. The fix is committed in the frontend repository as `625f465`; it has not yet been deployed.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-frontend-dockerfile-deployment-mismatch.md`
- `ProjectFlow-2026-10-15-staging-observability-deployment.md`

## References
- Frontend commit `625f465`
- Rolled-back frontend image ID
- `projectflow-hq/src/lib/constants.ts`

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
