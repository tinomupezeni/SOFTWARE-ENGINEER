# Nginx Upstream Port Conflict

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Local Docker Compose
**Severity:** High
**Status:** Resolved

## Summary
The frontend nginx container entered a restart loop because `nginx.conf`
declared an upstream named `backend` with port `8000`, then referenced that
upstream as `http://backend:8000`. Nginx rejected the configuration because a
named upstream group cannot be referenced with an additional port.

## Symptoms
- The backend container was healthy on port 8000.
- The frontend container repeatedly restarted.
- `localhost:8080` was unavailable.
- Frontend logs reported:
  `upstream "backend" may not have port 8000`.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Frontend nginx container
- **Related Components:** `swappify-social-hub/nginx.conf`,
  `docker-compose.yml`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Started the full Compose stack and checked container status, backend health,
frontend availability, and frontend logs.

### 2. Root Cause Analysis
The configuration contained:

```nginx
upstream backend {
    server backend:8000;
}

proxy_pass http://backend:8000;
```

The `backend` identifier refers to the declared upstream group, which already
contains port 8000. Nginx requires the proxy target to reference the upstream
group without another port.

### 3. Key Findings
- Backend health endpoint returned `{"ok": true, "service": "swap-o-sell"}`.
- Frontend nginx failed before opening port 80.
- The issue was isolated to all three `proxy_pass` directives in the frontend
  nginx configuration.

## Root Cause
The nginx upstream group and proxy target used incompatible forms of the
backend address.

## Prevention / Rule
**Guardrail:** Add `nginx -t` to the frontend image build or Compose health
check so invalid proxy configuration fails before the service is considered
ready.

This catches upstream/proxy syntax conflicts during image validation instead
of allowing a restart loop at runtime.

## Solution

### Immediate Fix
Changed the three proxy targets from `http://backend:8000` to
`http://backend`, allowing nginx to use the port defined by the upstream
group.

### Long-term Fix
Validate nginx configuration in CI and add a frontend health check to the
Compose service.

## Prevention
- [ ] Add `nginx -t` to CI or Docker build validation.
- [ ] Add a frontend HTTP health check to Compose.
- [ ] Keep upstream port ownership in one place.

## Related Issues
- None.

## References
- `/home/shadowe/Projects/swap-o-sell/swappify-social-hub/nginx.conf`

---

**Resolved By:** Copilot
**Time to Resolution:** Approximately 5 minutes
