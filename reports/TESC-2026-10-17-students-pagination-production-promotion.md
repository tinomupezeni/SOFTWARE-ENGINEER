# TESC students pagination production promotion

**Date:** 2026-10-17
**Project:** TESC
**Type:** Deployment / Release Readiness
**Status:** Completed with follow-up

## Summary
Promoted the exact backend image that passed staging verification to
`tesc-production` and recreated only the production backend and Celery worker.
The production Students API now returns bounded pages while preserving the
full filtered aggregate cards. Services remained restart-free, migrations were
clean, the frontend shell remained available, and the previous backend image
was preserved under a rollback tag.

## Context / Trigger
Production `/students` was serializing all 42,575 students despite the
frontend requesting `page_size=50`. The targeted fix was implemented and
verified on staging in TESC commit `4ce8252`.

## Scope
Included exact backend image promotion, production backend/worker recreation,
migration/readiness checks, authenticated Students API pagination smoke tests,
frontend shell verification, and rollback identity preservation. Public and
institution frontend images, database data, Redis, nginx, and unrelated
services were not changed.

## Method
Recorded staging and production image identities and migration state, preserved
the current production backend image, transferred the exact running staging
image without rebuilding, recreated the two affected services, and verified
the API contract over two pages plus service stability and frontend
availability.

## Decisions & Findings
- Staging release candidate:
  `tinotenda762/tesc-backend:latest`,
  manifest/container reference `sha256:1698b2a909f44bcb206ecd7a127c0e88b87608775ab8863d2048447eb11307ed`.
- Production now runs the transferred platform image ID
  `sha256:32141528ee045883a4abb27647c2380c440c0b07d05506f5309e15368dd5c5a3`;
  its ten filesystem layers match the staging image exactly.
- Previous production image
  `sha256:9d651018a925d90e1d9328d9ebf342fe7d8f046b403dfb1a8ccd326b41dba14f`
  is retained as
  `tinotenda762/tesc-backend:rollback-students-pagination-20261017`.
- Only `backend` and `celery-worker` were recreated. Frontend and
  infrastructure services were left untouched.
- A pre-existing duplicate seed-admin traceback occurred during startup
  because `/app/startup.sh` checks the seed email but inserts a fixed
  username already used by another production account. The script suppresses
  this with `|| true`; Gunicorn started, services did not restart, and the
  issue is separately logged for correction.

## Changes Made
- Promoted the verified staging backend image to production.
- Retagged it to the existing production Compose tag
  `tinotenda762/tesc-backend:fb060cc`.
- Recreated `tesc-main-backend-1` and `tesc-main-celery-worker-1`.
- Preserved the previous image rollback tag.

## Verification
- Production `migrate --check`: passed.
- Production Students API page 1:
  HTTP 200, 10 results, `count=42,575`,
  `total_students=42,575`, with gender and special-enrollment aggregates.
- Production Students API page 2:
  HTTP 200, 10 results, `count=42,575`, previous-page link present.
- Backend and worker restart counts: `0` after the stability window.
- Production frontend `/students` shell: HTTP 200.
- Staging source regression proof before promotion: 2 focused tests passed.
- Rollback image identity was verified and remains available.

## Follow-ups / Deferred
- Fix and regression-test idempotent seed-admin bootstrap; see
  `Backend_and_API/TESC-2026-10-17-startup-duplicate-admin-traceback.md`.
- Add response-size and latency monitoring for the Students endpoint.
- Resolve pre-existing `iseop` model/migration drift reported by startup.

## References
- TESC commit `4ce8252`
- Staging implementation report:
  `reports/TESC-2026-10-17-students-pagination-staging-implementation.md`
- Pagination issue log:
  `Backend_and_API/TESC-2026-10-17-students-page-unpaginated-production.md`
- Startup issue log:
  `Backend_and_API/TESC-2026-10-17-startup-duplicate-admin-traceback.md`

---

**Completed By:** Copilot
**Duration:** Same session
