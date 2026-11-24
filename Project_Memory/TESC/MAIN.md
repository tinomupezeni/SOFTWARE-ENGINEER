# TESC / ScalarEye — Memory Index

**Last updated:** 2026-11-24  
**Project repo:** `/home/shadowe/Projects/TESC`  
**One-line what-it-is:** National-scale higher education sector management system for Zimbabwe (ZCHPC), providing institution-scoped operations and national superadmin analytics across universities, polytechnics, and colleges.

Read this file first, every session, before touching the codebase. It should be enough to understand what the project is and why it's built the way it is without reading source. If something here is stale or wrong, fix it in the same session you notice — don't leave it for later.

## What this project is
TESC (product name **ScalarEye**) is a national-scale tertiary education record-keeping and analytics platform for Zimbabwe (ZCHPC). It replaces fragmented paper/Excel institutional record-keeping with a single system of record for students, staff, academic structures, programs, graduates, scholarships, placements, and innovation hubs. It features a single Django REST API serving two separate React frontends: one for institution administrators (`inst/`) with strict institution-scoped data isolation, and one for national superadmins (`frontend/`) for system-wide cross-institutional analytics and administration.

## Current state
- **Production & Staging:** Staging runs on VM `10.50.1.37`, Production on `10.50.200.35`. Both environments use Docker Compose. Staging exposes ports directly (`8000`, `8081`, `8082`); Production uses Nginx reverse proxying domains (`tesc.zchpc.ac.zw`, `tesc-inst.zchpc.ac.zw`).
- **Current Branch:** `feat/hide-demo-institution-reports` (ahead of deployed HEAD with changes hiding demo/sales institutions from system-wide aggregates and report studio pickers).
- **Testing:** Standalone smoke test suite (~40 scripts `smoke_test_*.py`) targeting the live staging API, plus Vitest suites on the frontend.
- **CI/CD:** Manual SSH/SFTP deployment process using tarball images (`tinotenda762/tesc-backend`, `tesc-main`, `tesc-inst`), migrating via startup scripts.

## Map
- `architecture/` — System topology (Django + Postgres 15 + Redis + Celery + dual React frontends), data models, and institutional isolation mechanics.
- `decisions/` — Architectural decisions: `Student` as single source of truth, `Person` shared identity, `Graduate` table synchronization, Fernet encrypted fields (`national_id`), dual auth flows.
- `implementation/` — Service layer patterns (`<app>/services/`), bulk upload pipeline (pandas + two-step approval), `InstitutionalIsolationMixin`, and frontend query caching patterns.
- `prompts/significant-tasks.md` — Prompts and tasks producing key architecture/refactoring milestones.
- `change-history/` — Architectural history including the frontend refactor phases and report studio demo institution isolation.

## Known gaps / don't trust this for
- Observability: Sentry is integrated on backend, but OpenTelemetry and Prometheus are not yet configured despite the engineering guide target.
- Automated CI/CD: Automated GitHub Actions deployments are not active; deploys are manual runbook operations via SSH/tarballs.
- Contract Testing: No automated pact/contract tests between Django DRF and React apps; rely on smoke test suite against running backend.

## Related
- Bug/issue log entries: `SOFTWARE-ENGINEER` technical-area folders with prefix `TESC-`.
- Reports: `SOFTWARE-ENGINEER/reports/` with prefix `TESC-`.
- Internal project docs: `project_docs/` in the TESC repository.
