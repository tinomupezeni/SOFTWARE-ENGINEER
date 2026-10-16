# TESC Endpoint Checklist Audit

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Type:** Audit / End-to-end verification
**Status:** In Progress

## Summary
Created and executed a tracked staging endpoint checklist covering 86 concrete API route/method entries across users, institution auth, academic, faculties, staff, innovation, ISEOP, analysis, reports, and task status. The current result is 85 passing checks and one unresolved route failure: `/api/academic/graduates-mgmt/` returns HTTP 404.

## Context / Trigger
The user requested a complete endpoint-by-endpoint verification with an explicit pass/fail checklist rather than a broad smoke-test claim.

## Scope
Included authenticated read-only endpoint checks, safe invalid-input validation probes, route reachability checks for detail endpoints, report and ingestion edge cases, and the existing institution bulk-upload verification. Destructive CRUD success paths requiring persistent test fixtures were not performed by generic probes.

## Method
1. Enumerated route families from Django URL configurations.
2. Created the session `endpoint_checklist` table with one row per route/method contract.
3. Corrected the probe target to the staging backend container and supplied an accepted Django `Host` header.
4. Generated a fresh staging superuser token for authenticated checks.
5. Ran read-only checks and safe invalid-input probes, recording HTTP behavior and evidence per row.
6. Fixed two server errors discovered during probing and redeployed staging.

## Decisions & Findings
- 85 of 86 checklist entries pass.
- `/api/academic/graduates-mgmt/` is the only unresolved failure; it returns HTTP 404 despite a `GraduateViewSet` registration in deployed source.
- Legacy report generation previously returned HTTP 500 for a missing `report_type`; it now returns HTTP 400.
- Ingestion commit previously returned HTTP 500 when a superuser had no institution; it now returns HTTP 400 with an institution-required error.
- The host smoke configuration targeted an unrelated localhost service; the actual backend required container-network targeting.
- Existing bulk-upload end-to-end coverage passed all 14 institution upload flows.

## Changes Made
- Added required-field validation in `backend/reports/services.py`.
- Guarded nullable institution context in `backend/academic/app_views/ingestion_views.py`.
- Committed TESC fixes in commit `c9cef4f`.
- Recorded related issue logs:
  - `TESC-2026-10-16-graduates-management-route-missing.md`
  - `TESC-2026-10-16-legacy-report-missing-type-500.md`
  - `TESC-2026-10-16-ingestion-commit-superuser-500.md`
  - `TESC-2026-10-16-staging-endpoint-probe-target-mismatch.md`

## Verification
- Authenticated smoke endpoints: 34/34 passed.
- Extended read-only/custom GET endpoints: 22/22 passed after valid parameter correction.
- Auth and report validation probes: passed except the initially fixed legacy report endpoint, which passed after redeployment.
- Final checklist: **85 PASS, 1 FAIL**.
- Staging backend rebuilt and restarted after both fixes.

## Follow-ups / Deferred
- Resolve why the deployed Django resolver does not expose `/api/academic/graduates-mgmt/`.
- Add role-matrix and route-resolution tests to CI.
- Add isolated success-path fixtures for generic CRUD endpoint testing.
- Persist the endpoint checklist as a repository artifact if cross-session historical tracking is required; the current checklist is maintained in the session database.

## References
- `backend/academic/urls.py`
- `backend/academic/app_views/graduate_views.py`
- `backend/reports/services.py`
- `backend/academic/app_views/ingestion_views.py`
- Session table: `endpoint_checklist`

---

**Completed By:** Copilot
**Duration:** One staging verification session; graduate route investigation remains open
