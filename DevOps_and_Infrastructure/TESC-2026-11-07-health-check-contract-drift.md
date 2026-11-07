# Production health-check contract is not wired to the documented endpoints

**Date:** 2026-11-07
**Project:** TESC
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The documented TESC production health and readiness endpoints do not exist on
the live backend route. The documented API probes return 404, while the
undecorated `/health` and `/readiness` paths are served by the frontend
fallback, so a 200 response from those paths does not prove backend or
dependency readiness.

## Symptoms
- `/api/infrastructure/health/` returns 404.
- `/api/infrastructure/readiness/` returns 404.
- `/api/health/` returns 404.
- `/health`, `/readiness`, `/health/live`, and `/health/ready` return the
  frontend HTML document rather than a health payload.
- Database and Redis themselves respond successfully, but the gateway health
  journey does not prove that the backend is ready.

## Environment Details
- **Server/Host:** `tesc-prod` (`10.50.200.35`)
- **Services Affected:** nginx routing and backend observability contract
- **Related Components:** `nginx/nginx.conf`, production readiness
  documentation, deployment runbook
- **Time First Observed:** 2026-11-07 18:20 +02:00

## Investigation Steps

### 1. Initial Diagnosis
Probed the documented health paths through nginx using the production and
inactive-color Host headers.

### 2. Root Cause Analysis
The live route table has normal API routing under `/api/`, but no matching
health endpoint was found in the deployed backend route. Nginx sends
unmatched non-API paths to the frontend, producing a success-shaped HTML
response.

```bash
curl -H 'Host: tesc.zchpc.ac.zw' http://127.0.0.1/api/infrastructure/health/
curl -H 'Host: tesc.zchpc.ac.zw' http://127.0.0.1/health
```

### 3. Key Findings
- Both blue and green migration plans report no pending migrations.
- PostgreSQL reports accepting connections and Redis returns `PONG`.
- The current HTTP probes cannot distinguish a healthy backend from a working
  frontend fallback.

## Root Cause
The health-check documentation and release observer are out of sync with the
deployed URL configuration, and nginx's frontend fallback masks missing
backend health routes with HTTP 200.

## Prevention / Rule
**Guardrail:** Require the production smoke script to assert both the expected
content type/payload and the backend health route's non-404 status; a frontend
HTML response must fail the release check even if its HTTP status is 200.

This prevents the observer from certifying frontend availability as backend
readiness.

## Solution

### Immediate Fix
No production mutation was performed. The deployment was treated as
unverified for backend health.

### Long-term Fix
Choose one canonical backend health/readiness contract, wire it through nginx
without frontend fallback ambiguity, and update the runbook and smoke tests to
validate its response body and dependencies.

## Prevention
- [ ] Define and implement canonical liveness/readiness routes
- [ ] Update nginx and deployment documentation to the same contract
- [ ] Make smoke checks reject HTML fallback responses

## Related Issues
- `TESC-2026-11-07-green-artifact-identity-drift.md`

## References
- `docs/production-readiness/OBSERVABILITY.md`
- `docs/production-readiness/DEPLOYMENT_RUNBOOK.md`
- Production probe results from `tesc-prod`, 2026-11-07

---

**Resolved By:** Copilot
**Time to Resolution:** Not resolved; observer contract requires repair
