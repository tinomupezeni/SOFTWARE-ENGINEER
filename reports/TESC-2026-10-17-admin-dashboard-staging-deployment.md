# TESC Admin Dashboard Staging Deployment

**Date:** 2026-10-17  
**Project:** TESC  
**Type:** Deployment  
**Status:** Completed

## Summary

Deployed the Django admin dashboard update to the TESC staging VM at
`10.50.1.37`, including admin operations views, white/blue styling, host
resource telemetry, and read-only backup inventory. The active staging
Compose topology was preserved, and no production services were changed.

## Context / Trigger

The admin dashboard implementation had passed local Django checks and focused
SQLite tests. The next requested step was deployment to staging for runtime
verification before any production consideration.

## Scope

Included the backend admin views, registrations, templates, styling, static
collection, nginx static serving, host metrics snapshot, backup inventory
mounts, migration checks, and staging smoke tests. Excluded production
deployment, hard deletion behavior, new database migrations, and unrelated
dirty staging checkout changes.

## Method

The local admin changes were transferred surgically to the existing staging
checkout rather than resetting its unrelated dirty state. The active runtime
was identified from the running containers and Compose labels. Migrations,
static collection, service recreation, dependency health, public routes,
static assets, mounts, restart counts, and deployment-window logs were then
verified independently.

## Decisions & Findings

- The active staging backend is served through the `docker-compose.prod.yml`
  topology and uses the existing `tesc-backend-1` container.
- No new migrations were pending. Django continued to report the known
  pre-existing `iseop` model-drift warning.
- Host resource telemetry initially exposed a mount-layout problem because a
  nested read-only bind mount under `/run/tesc` could not be created. The
  backup inventory was moved to `/run/tesc-backups`, with an explicit settings
  path.
- The admin CSS initially returned 404 because nginx proxied static requests
  to Gunicorn. Nginx was changed to serve collected static files through a
  read-only alias.
- The staging disk snapshot reported 85% usage, which is above the configured
  warning threshold and should be monitored.

## Changes Made

- Deployed admin source files and templates to the staging checkout.
- Ran `collectstatic --noinput`.
- Added staging telemetry and backup mounts to the active backend service.
- Added nginx static alias and read-only staticfiles mount.
- Recreated the backend and reloaded nginx.
- Removed two duplicate frontend containers created while reconciling the
  separate Compose topology; the pre-existing `*-v2` frontend containers
  remained in service.

## Verification

- Local `manage.py check`: passed.
- Local focused `AdminOperationsTests`: 6 tests passed.
- Staging `manage.py migrate --check`: passed; no unapplied migrations.
- Staging `manage.py check`: passed.
- Main staging frontend: HTTP 200.
- Institution staging frontend: HTTP 200.
- `/admin/login/`: HTTP 200.
- Unauthenticated `/admin/operations/`: HTTP 302 to the login page.
- `/static/admin/tesc_admin.css`: HTTP 200, `text/css`.
- Backend, nginx, database, Redis, and worker containers running.
- Backend and nginx restart counts: 0 after final recreation.
- Host metrics and backup inventory mounts verified inside the backend.
- Deployment-window error scans returned no new backend or nginx errors.

## Follow-ups / Deferred

- Run an authenticated browser journey using an approved staging admin
  account, including dashboard metrics, audit entries, and user activation.
- Add the static-asset smoke check to the automated staging release gate.
- Resolve the pre-existing `iseop` model-drift warning separately.
- Investigate the staging disk warning before it reaches the critical
  threshold.
- Consolidate the duplicate/legacy Compose topologies to prevent future
  service recreation ambiguity.

## References

- `DevOps_and_Infrastructure/TESC-2026-10-17-admin-static-assets-not-served.md`
- `reports/TESC-2026-10-17-admin-ops-telemetry.md`
- `backend/users/admin_views.py`
- `nginx/nginx.conf`
- `docker-compose.prod.yml`

---

**Completed By:** Copilot  
**Duration:** One staging deployment session
