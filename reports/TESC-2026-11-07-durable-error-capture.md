# Durable backend error capture

**Date:** 2026-11-07
**Project:** TESC
**Type:** Observability / Database-backed error tracking
**Status:** Completed

## Summary
Added durable persistence for backend and worker error events so application error history survives Docker image rebuilds. The feature records request failures and ERROR/CRITICAL logger events in PostgreSQL, redacts common secret values, and exposes records through Django admin. The implementation was deployed and migration-applied to the idle green production color at `0a1a76d`; public traffic remains on blue.

## Context / Trigger
The user requested a persistent alternative to relying on Docker logs, with historical traces retained across image rebuilds. The existing logging path did not provide a database-backed error history.

## Scope
Included Django request exceptions, handled DRF 500 responses, backend/Celery logger events, request IDs, release metadata, redaction, tenant/user attribution, migration, admin visibility, and idle-color deployment verification.

Explicitly excluded nginx errors, frontend static-server errors, Docker daemon/container lifecycle failures, and host/VPS failures because Django middleware cannot observe those layers. Those require host-level logging or a separate collector.

## Method
Inspected the existing middleware, exception handler, logging configuration, tenant context, deployment compose file, and migration policy. Implemented the smallest backend/database boundary, added focused SQLite-backed tests, ran Django checks and migration consistency checks, deployed only to the idle color, applied the migration, and performed route and controlled-error smoke tests.

## Decisions & Findings
- `observability.ErrorEvent` is the durable PostgreSQL record.
- Request middleware captures unhandled exceptions and adds `X-Request-ID`.
- The DRF exception handler captures handled 500 responses.
- A database logging handler captures ERROR and CRITICAL backend/Celery logs without recursively recording its own persistence failures.
- Stored messages and tracebacks redact authorization, password, token, secret, API-key, and access-token values.
- Release SHA is propagated from `IMAGE_TAG` into backend and worker containers.
- Current traffic remains blue; green is validated but not cut over.
- The deployment script needs an explicit production Compose project name when run from a temporary worktree; the deployment workaround is documented separately in `TESC-2026-11-07-blue-green-compose-project-collision.md`.

## Changes Made
- TESC commit `0a1a76d`: added the observability app, model, migration, middleware, logging handler, recorder, admin, tests, settings, exception-handler integration, and release SHA environment propagation.
- Applied `observability.0001_initial` on `backend-green`.
- Green service images and containers now run `0a1a76d`.

## Verification
- `USE_SQLITE=True python manage.py check`
- `USE_SQLITE=True python manage.py makemigrations --check --dry-run`
- `USE_SQLITE=True python manage.py test observability --verbosity 1` — 4 tests passed
- Python compile and `git diff --check` passed
- Main and institution staging host routes returned HTTP 200 from the production nginx path
- Controlled backend failure persisted an event with:
  - request ID `smoke-error-0a1a76d`
  - release SHA `0a1a76d`
  - HTTP status `500`
  - redacted message `controlled password=[REDACTED]`
- All four green services reported healthy after recreation.

## Follow-ups / Deferred
- Add explicit Celery task metadata such as task name, task ID, retry count, and queue.
- Add retention/archival and alerting policies for high-volume error rows.
- Add host-level collection for nginx, Docker, and VPS failures.
- Make `COMPOSE_PROJECT_NAME=tesc-main` a script-level invariant rather than a deployment invocation workaround.
- Do not cut over to green without explicit approval.

## References
- Issue: `SOFTWARE-ENGINEER/Backend_and_API/TESC-2026-11-07-durable-error-capture-context-and-startup.md`
- Issue: `SOFTWARE-ENGINEER/DevOps_and_Infrastructure/TESC-2026-11-07-blue-green-compose-project-collision.md`
- TESC files: `backend/observability/`, `backend/core/settings.py`, `backend/core/exceptions.py`, `docker-compose.bluegreen.yml`

---

**Completed By:** Copilot
**Duration:** Same engineering session
