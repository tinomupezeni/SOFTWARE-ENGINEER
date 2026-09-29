# Staging rebuild from main on erp-vm

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Type:** Deployment (staging rebuild)
**Status:** Completed

## Summary

Synced the VM staging dir to `main` (`f5b4c00`), rebuilt all three
staging images from source, and brought the stack healthy with migrations
applied and original data preserved. Two blocking incidents (portal
type error, compose name collision) were found and fixed along the way;
prod was untouched throughout. Prod redeploy is deliberately deferred
pending approval.

## Context / Trigger

VM staging images were ~4 weeks old and prod `:latest` images ~11 days
old, while local `main` had landed purchase-requisition workflow,
reviewer notifications, chart-of-accounts import, and RBAC seeds. Request:
pull latest code into the VM and rebuild images.

## Scope

- Included: `~/zchpc-erp-staging` sync to `main`, rebuild of staging
  `api`/`frontend`/`portal` images, health + migration verification,
  dev-log entries.
- Explicitly excluded: **prod stack** (`~/zchpc-erp`, `tinotenda762/*`)
  — rebuilding/repointing prod needs its own approval (staging-first
  rule). Also excluded: changing staging `.env` values (e.g. the
  `VITE_API_URL` default pointing frontends at prod API — flagged below).

## Method

1. Inspected VM state first (containers, images, compose, `.env` keys,
   disk, github reachability) before changing anything.
2. Cloned `main` fresh on the VM, backed up VM-only helpers
   (`check_db.py`, `reset_pass.py`, `test_login.py`, `unlock_user.py`)
   and `.env`, then rsynced into the staging dir excluding `.env` —
   preserving port remaps and leaving the dir with a `.git` for future
   plain `git pull` syncs.
3. `docker compose up -d --build`, then health + log verification in
   both directions (new behavior live, nothing else broken).

## Decisions & Findings

- **Portal didn't compile on `main`** (TS2304, missing `vite-env.d.ts`,
  from F27-PR). Fixed with a 3-line declaration mirroring the admin
  frontend; verified `tsc -b` + `vite build` locally. Direct push to
  `main` was rejected by branch protection → fix branch + PR #32, merged
  (`f5b4c00`). Own bug-log entry filed.
- **Canonical compose collides with prod on one host** (absolute
  `container_name`/`name:`). Fixed with a VM-local
  `docker-compose.override.yml` (staging-scoped names, original pgdata
  volume). Own bug-log entry filed. Long-term: template names or ship a
  staging overlay in git.
- Staging `.env` sets no `VITE_API_URL`, so rebuilt frontends bake the
  Dockerfile default (`https://zchpcerp.zchpc.ac.zw`, i.e. prod origin).
  Left as-is (same as previous build) but this deserves a deliberate
  decision before prod redeploy.

## Changes Made

- `employee-portal/src/vite-env.d.ts` (new, via PR #32, merged `f5b4c00`)
- VM `~/zchpc-erp-staging`: synced to `f5b4c00`; new images
  `zchpc-erp-staging-{api,portal,frontend}:latest`; new VM-local
  `docker-compose.override.yml`; backups in `~/staging-backup-20260929/`;
  `~/zchpc-erp-fresh/` clone removed-or-kept (kept for reference).
- Containers now `zchpc_staging_{api,db,frontend,portal}`, all healthy.

## Verification

- `curl :8001/api/v2/health/` → `{"status":"healthy"}`; `:3010`/`:3011`
  `/health` → 200.
- API logs show `portal.0003` + `procurement.0008–0014` migrations `OK`,
  no tracebacks.
- New procurement routes live: `GET .../procurement/purchase-requests/`
  → 401 (exists, auth-gated) instead of 404.
- Prod re-checked after every staging step: `:8000` healthy, all four
  `zchpc_*` containers `Up (healthy)`, RestartCount 0.

## Follow-ups / Deferred

- Prod redeploy (repoint `tinotenda762/*:latest` or switch prod to build
  from source) — needs explicit approval; staging-first evidence is ready.
- Decide staging `VITE_API_URL` (own build arg vs prod default).
- Canonical compose naming fix + CI build gate (in bug-log Prevention
  sections); `~/zchpc-erp-fresh` cleanup on VM.

## References

- Bug logs: `Frontend_and_UI/ZCHPC-2026-09-29-portal-build-ts2304-missing-vite-env.md`,
  `DevOps_and_Infrastructure/ZCHPC-2026-09-29-staging-compose-absolute-names-collision.md`
- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/32

---

**Completed By:** Muse Spark (opencode)
**Duration:** ~1h
