# ProjectFlow observability backend had no frontend surface

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
ProjectFlow had deployed observability APIs and registered VPS telemetry, but the frontend had no route, navigation entry, API client paths, or page for administrators to view VPS health.

## Symptoms
- The sidebar exposed workspace and administration pages but no VPS observability page.
- The frontend contained no observability route or API client.
- The backend observability endpoints were available at `/api/observability/status/`, `/events/`, and `/alerts/`.

## Environment Details
- **Server/Host:** `restk-vps`
- **Services Affected:** ProjectFlow frontend navigation
- **Related Components:** `projectflow-hq/src/App.tsx`, `AppSidebar.tsx`, `src/lib/constants.ts`, observability API
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the deployed navigation and frontend routes after confirming the backend observability endpoints existed.

### 2. Root Cause Analysis
The observability rollout implemented backend telemetry ingestion and status APIs but did not complete the frontend consumer path.

```bash
GET /api/observability/status/
GET /api/observability/events/?limit=50
GET /api/observability/alerts/
```

### 3. Key Findings
- Backend API and administrator authorization were present.
- No frontend page or navigation item referenced the API.
- The missing surface was a cross-layer completion gap, not a telemetry ingestion failure.

## Root Cause
The observability feature was delivered through backend and deployment layers without wiring the administrator-facing UI route and navigation.

## Prevention / Rule
**Guardrail:** Require every multi-layer feature to include a reachable UI/API smoke test from the user navigation entry point before release.

This verifies that backend functionality is not considered complete until the intended consumer can reach and exercise it.

## Solution

### Immediate Fix
Added an admin-only VPS Observability page at `/infrastructure` with fleet health, resource metrics, container state, active alerts, recent events, refresh, polling, and alert acknowledgement.

### Long-term Fix
Add a release acceptance check covering the navigation link, protected route, API response, and rendered telemetry state.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-staging-observability-deployment.md`
- `ProjectFlow-2026-10-15-frontend-source-drift-regression.md`

## References
- Frontend commit containing the page
- Backend `observability/views.py`
- Backend `observability/urls.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same release session
