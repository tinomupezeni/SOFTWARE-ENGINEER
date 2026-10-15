# ProjectFlow observability UI surface

**Date:** 2026-10-15
**Project:** ProjectFlow
**Type:** Feature completion / Cross-layer integration
**Status:** Completed

## Summary
Completed the missing administrator-facing frontend surface for the already deployed ProjectFlow observability backend. Administrators can now open VPS Observability from the Management sidebar and view fleet health, resources, containers, active alerts, and recent events.

## Context / Trigger
The user could not find a page for the registered VPSes even though the observability API and telemetry agents had been deployed.

## Scope
Included frontend API paths, an admin-protected route, navigation, the observability dashboard, periodic refresh, and alert acknowledgement. Backend telemetry models and endpoints were not changed.

## Method
Traced the backend endpoint contract and frontend route/navigation structure, implemented the consumer UI using existing API and component patterns, built and linted the frontend, then prepared the frontend-only deployment.

## Decisions & Findings
- The page belongs under the admin-only Management section because backend observability endpoints require the `Admin` role.
- `/infrastructure` was selected as the route, with the user-facing label **VPS Observability**.
- The dashboard polls every 30 seconds and exposes manual refresh.

## Changes Made
- Added observability API paths to `src/lib/constants.ts`.
- Added `src/pages/Infrastructure.tsx`.
- Added the protected `/infrastructure` route in `src/App.tsx`.
- Added the Management sidebar entry in `src/components/AppSidebar.tsx`.

## Verification
- `npm run build`: passed.
- `npm run lint`: passed with 16 pre-existing warnings and no errors.
- Backend endpoint contract matched the deployed `/api/observability/` routes.

## Follow-ups / Deferred
- Add an end-to-end browser smoke test for the navigation-to-telemetry path.
- Add per-VPS drill-down history charts when historical trends are required.

## References
- `ProjectFlow-2026-10-15-observability-ui-missing-surface.md`
- Backend `observability/views.py`
- Frontend route `/infrastructure`

---

**Completed By:** Copilot
**Duration:** Same release session
