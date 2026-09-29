# Prod promotion: retag staging images to prod on erp-vm

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Type:** Deployment (prod cutover)
**Status:** Completed

## Summary

Promoted the verified staging images (built from `main` `f5b4c00`) to
prod by retagging — no prod-side rebuild, per decision. Prod recreated
healthy with migrations applied and row counts unchanged (34 employees,
7 users, 0 payrolls). Rollback refs and a pre-cutover DB dump recorded.

## Context / Trigger

Staging rebuild (prior report) was verified healthy; prod still ran
11-day-old `:latest` images. Decision: copy stable staging images over
prod tags instead of rebuilding on prod.

## Scope

- Included: pre-cutover `pg_dump` of prod DB, retag of the three images,
  `docker compose up -d` in `~/zchpc-erp`, health/migration/data
  verification.
- Excluded: pushing tags to Docker Hub (`tinotenda762/*:latest` upstream
  still holds the old images — local tags only); any `.env`/config change.

## Method

1. Recorded running prod image IDs for rollback; dumped prod DB to
   `~/prod-backup-20260929.sql.gz` (45 KB).
2. Recorded pre-cutover counts: `hr_employees=34`,
   `authentication_customuser=7`, `payroll_payroll=0`.
3. `docker tag zchpc-erp-staging-{api,frontend,portal}:latest
   tinotenda762/zchpc-erp-{api,frontend,portal}:latest`, then
   `docker compose up -d` in `~/zchpc-erp` (prod `IMAGE_TAG=latest`
   picks the new IDs up).
4. Verified both directions: new behavior live, old behavior intact,
   counts identical.

## Decisions & Findings

- Retag-over-rebuild chosen to avoid a second long build and guarantee
  prod runs the exact bytes already soaked on staging.
- Old prod images remain as untagged layers (`2cf486d7` api,
  `17cb79e0` frontend, `664cd02c` portal) — instant rollback via retag
  if needed.
- Frontend build-arg note: neither staging nor prod `.env` sets
  `VITE_API_URL`, so both bake the Dockerfile default
  (`https://zchpcerp.zchpc.ac.zw`). Promoted images behave exactly like
  the previous prod ones in this respect — no behavior change, but the
  value deserves a deliberate review (see staging report follow-ups).

## Changes Made

- VM-local image tags only; no git changes. Prod containers recreated:
  `zchpc_api` (image `5d67bf87...`, = staging build), `zchpc_frontend`,
  `zchpc_portal` — all `healthy`. `zchpc_db` untouched (data volume
  preserved, container from Sep 25).

## Verification

- `:8000/api/v2/health/` → `{"status":"healthy"}`; `:3000`, `:3001`
  `/health` → 200.
- New procurement routes live on prod:
  `GET /api/v2/procurement/purchase-requests/` → 401 (was 404 on old).
- API logs: `procurement.0010–0014` (and earlier chain) `OK`, no
  errors/tracebacks.
- Post-cutover counts `34|7|0` — identical to pre-cutover.

## Follow-ups / Deferred

- Push promoted tags to Docker Hub if registry is source of truth for
  other hosts (currently only this VM consumes them).
- Same follow-ups as staging report: `VITE_API_URL` decision, canonical
  compose naming fix, CI build gate.

## References

- Prior report: `reports/ZCHPC-2026-09-29-staging-rebuild-from-main.md`
- Backup: `~/prod-backup-20260929.sql.gz` on erp-vm

---

**Completed By:** Muse Spark (opencode)
**Duration:** ~20 min
