# TESC Admin Operations Telemetry

**Date:** 2026-10-17  
**Project:** TESC  
**Type:** Feature / Observability / Operations  
**Status:** Completed locally; staging deployment deferred

## Summary

Extended the Django operations dashboard with the real system's white-and-blue
visual treatment, read-only VM resource telemetry, and backup-copy inventory.
The implementation uses a host-written JSON snapshot and explicitly configured
read-only backup mounts so the dashboard reports actual evidence or an
unavailable/stale state instead of inferring health.

## Context / Trigger

The one-week user-testing exercise requires administrators to see whether the
VM is approaching CPU, memory, or disk limits and whether database backups
sent to a staging VM and retained copies are present. The initial dashboard
showed application-level counts and database/cache health but had no VM or
backup visibility.

## Scope

Included:

- White/blue TESC styling for Django admin branding, navigation, modules, and
  resource status indicators.
- Configurable host metrics snapshot path and freshness limit.
- Host collector script for CPU, memory, disk, load, hostname, and timestamp.
- Configurable read-only backup inventory path.
- Bounded backup metadata listing for recognized backup extensions.
- Freshness, numeric-validation, missing-source, and authorization tests.
- Compose read-only mounts for host status and backup directories in the
  regular and staging configurations.

Excluded:

- SSH access from Django to another VM.
- Remote backup verification from production against staging.
- Reading or downloading backup contents through the web interface.
- Automatic cleanup, restore, deletion, or mutation of backups.
- Production or staging deployment.

## Method

Reviewed the existing backup scripts and Compose topology, then added a
least-privilege read path: a host-side collector writes an atomic JSON
snapshot, while Django reads only the configured snapshot file and configured
backup directory through read-only mounts. The dashboard bounds the number of
listed files, filters to recognized backup suffixes, validates timestamps and
finite numeric values, and exposes no file contents.

## Decisions & Findings

- VM metrics must come from a host-side collector rather than relying on
  container-local assumptions. A missing or stale snapshot is shown as
  unavailable.
- Backup visibility is intentionally local to the VM hosting the dashboard.
  On staging, the configured directory is `/home/user/tesc_backups`, matching
  the existing transfer script. On the regular Compose deployment, the host
  directory is configurable through `TESC_BACKUP_HOST_DIR`.
- The dashboard lists at most 100 recognized backup files and displays names,
  byte sizes, and modification times only.
- CPU utilization is unavailable on the collector's first run because a
  previous `/proc/stat` sample is required; subsequent runs calculate the
  interval usage. Memory, disk, and load are available immediately.
- No cross-VM verification is claimed by this change. A staging dashboard
  mounted to the staging backup directory is the authoritative view of files
  present on staging.

## Changes Made

- `backend/users/admin_views.py`: added validated host metrics and backup
  inventory readers.
- `backend/users/templates/admin/operations_dashboard.html`: added VM and
  backup panels with explicit status states.
- `backend/users/static/admin/tesc_admin.css`: added white/blue admin theme.
- `backend/templates/admin/base_site.html`: loaded the custom admin CSS.
- `backend/core/settings.py`: added configurable telemetry paths, freshness,
  and thresholds.
- `docker-compose.yml` and `docker-compose.staging.yml`: added read-only host
  status and backup mounts.
- `scripts/collect_host_metrics.sh`: added atomic host snapshot collection.
- `backend/users/tests.py`: added telemetry, missing-source, inventory, and
  theme regression coverage.

## Verification

- `cd backend && .venv/bin/python manage.py check` passed.
- `cd backend && USE_SQLITE=True .venv/bin/python manage.py test users.tests.AdminOperationsTests --verbosity 1` passed: 6 tests.
- `docker compose -f docker-compose.yml config --quiet` passed.
- `docker compose -f docker-compose.staging.yml config --quiet` passed.
- `bash -n scripts/collect_host_metrics.sh` passed.
- The collector was run twice and its JSON was parsed successfully, including
  CPU interval output.
- `git diff --check` passed.
- PostgreSQL-backed tests and live staging browser verification remain
  deferred; no deployment was performed.

## Follow-ups / Deferred

- Configure the host cron/systemd timer on staging and production to run
  `scripts/collect_host_metrics.sh` into `/run/tesc/host-metrics.json`.
- Configure `TESC_HOST_STATUS_DIR` and `TESC_BACKUP_HOST_DIR` on each VM,
  verify permissions, and confirm the mounted paths contain the intended
  files before rebuilding/recreating services.
- Deploy to staging and perform a real admin journey showing current resource
  values and the actual `/home/user/tesc_backups` inventory.
- Add explicit “last successful backup age” and retention warnings once the
  backup naming/retention policy is standardized.
- If administrators need production-to-staging confirmation from one screen,
  add a signed, push-based backup manifest rather than SSH credentials or a
  Docker socket mount.

## References

- `scripts/backup_to_staging.sh`
- `scripts/backup_database.sh`
- `docker-compose.yml`
- `docker-compose.staging.yml`
- `backend/users/admin_views.py`
- `backend/users/templates/admin/operations_dashboard.html`

---

**Completed By:** Copilot  
**Duration:** One implementation session
