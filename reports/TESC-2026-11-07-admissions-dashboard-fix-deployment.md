# Admissions Dashboard Fix and Idle-Color Deployment

**Date:** 2026-11-07
**Project:** TESC
**Type:** Bug Fix / Contract Correction / Deployment
**Status:** Completed

## Summary
Fixed invalid `NaN`/null values on the main Admissions dashboard and added institution filtering. The exact commit was pushed to GitHub and deployed to the idle green color on `tesc-prod` without changing public traffic.

## Context / Trigger
The staging Admissions page showed invalid top-program values and lacked the requested institution filter. Source inspection found that the backend permitted null program groups and the frontend had no institution query contract or display normalization.

## Scope
Included the Admissions API, its frontend service contract, the Admissions page, focused regression tests, and deployment to the idle color. Excluded blue-green cutover and authenticated user-journey verification because no cutover was requested and no authenticated browser session was available.

## Method
Traced the response from the Django query through the TypeScript service to the rendered cards/list. Added producer-side filtering for null programs, consumer-side normalization for invalid values, an institution query parameter, and a selector backed by the existing institutions endpoint. Built and tested locally, then deployed the exact Git SHA using the repository blue-green deployment script.

## Decisions & Findings
- Institution filtering applies to regular and ISEOP student aggregates.
- Top-program groups exclude students with no linked program.
- `null`, empty, and case-insensitive `NaN` display values render as `N/A`; invalid numeric values render as zero.
- Blue remains active; green is the verified idle release candidate.

## Changes Made
- Commit `68c9369` pushed to `tinomupezeni/TESC` branch `staging`.
- Updated `backend/analysis/views/admissions_views.py`.
- Updated `frontend/src/pages/Admissions.tsx`.
- Updated `frontend/src/services/analysis.services.ts`.
- Added `frontend/src/utils/admissions.ts`.
- Added `frontend/src/pages/Admissions.test.tsx`.
- Deployed green images tagged `68c9369`.

## Verification
- Focused frontend tests: 2 passed.
- Targeted ESLint: passed.
- Frontend production build: passed.
- Backend module compilation: passed.
- Green services: backend, worker, main frontend, and institution frontend all running `68c9369`.
- Migration plan: no pending operations.
- nginx configuration test: successful inside the nginx container.
- Staging Admissions route: HTTP 200 and new institution-filter bundle marker present.
- Admissions API without credentials: HTTP 401, confirming protected route behavior.
- Active color remained blue (`94bf94e`); no cutover performed.

## Follow-ups / Deferred
- Perform an authenticated staging check that selects an institution and confirms the returned aggregates change.
- Cut over only after explicit approval and the authenticated journey passes.
- Add backend fixture-based integration coverage for institution-scoped admissions aggregates.

## References
- `Frontend_and_UI/TESC-2026-11-07-admissions-dashboard-nan-institution-filter.md`
- `backend/analysis/views/admissions_views.py`
- `frontend/src/pages/Admissions.tsx`
- `frontend/src/services/analysis.services.ts`
- `scripts/bluegreen-deploy.sh`

---

**Completed By:** Copilot
**Duration:** Same session
