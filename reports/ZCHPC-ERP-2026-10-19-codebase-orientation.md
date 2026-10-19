# ZCHPC ERP Codebase Orientation

**Date:** 2026-10-19
**Project:** ZCHPC ERP
**Type:** Audit / Repository Orientation
**Status:** Completed

## Summary
Read the ZCHPC ERP repository to establish its application boundaries, runtime
stack, API routing, authentication shape, frontend entrypoints, and current
repository state before future engineering work.

## Context / Trigger
The user requested that the codebase be read. This was an orientation pass, not
an implementation or defect-remediation request.

## Scope
Included the root documentation, Django settings and root URLs, module layout,
backend dependency/test configuration, both Vite frontend manifests and
entrypoints, frontend route/auth/API boundaries, deployment documentation, and
the current Git status.

Explicitly excluded resolving source conflicts, changing application code,
running a production deployment, and making claims about end-to-end behavior
without a running target environment.

## Method
Read project and workspace engineering guidance first, then inspected the
repository map, architecture documentation, runtime manifests, central
entrypoints, API routing, authentication middleware/context, and Git conflict
state. A read-only architecture search was used to cross-check the main
backend/frontend boundaries.

## Decisions & Findings
- The backend is a Django 5.2 modular monolith under `erp_project/`, with
  source modules under `erp_project/src/modules/`.
- The API is versioned under `/api/v2/`; root routing mounts identity, BFF, HR,
  attendance, leave, recruitment, payroll, accounts, procurement, and portal
  modules.
- Backend settings use PostgreSQL by default, SQLite when `USE_SQLITE` is
  enabled, JWT authentication, fail-closed DRF permissions, CORS controls,
  module-access middleware, and RBAC middleware.
- The ERP admin frontend is a React/Vite/TypeScript application under
  `zchpc-erp-synergy-main/`, with protected dashboard, HR, payroll, accounting,
  procurement, inventory, sales, settings, and module routes.
- The employee portal is a separate React/Vite/TypeScript application under
  `employee-portal/`, combining public recruitment routes with authenticated
  attendance, leave, procurement, requisition, and payslip journeys.
- Frontend API clients target the backend `/api/v2/` surface and persist JWT
  tokens in browser storage; the admin and portal apps use separate auth
  contexts/services and token keys.
- The worktree is currently not a clean baseline: seven paths are unresolved
  conflicts, including four Django app configs and admin inventory/CRM files.
  This is recorded separately in the issue log referenced below.

## Changes Made
No application source files were changed. Two engineering records were added:

- `DevOps_and_Infrastructure/ZCHPC-ERP-2026-10-19-unresolved-merge-conflicts.md`
- `reports/ZCHPC-ERP-2026-10-19-codebase-orientation.md`

## Verification
Verified by direct file reads, architecture search, and:

```bash
git status --short --branch
git diff --stat
git diff --name-only --diff-filter=U
```

No build, test, migration, or live smoke command was run because this request
was read-only and the worktree contains unresolved conflicts.

## Follow-ups / Deferred
- Resolve the existing merge conflicts before treating the branch as a stable
  implementation baseline.
- Run backend tests and both frontend lint/build suites after conflict
  resolution.
- Perform contract-level API/client verification for any future cross-boundary
  changes.

## References
- `ZCHPC-ERP/GEMINI.md`
- `ZCHPC-ERP/erp_project/erp_root/settings.py`
- `ZCHPC-ERP/erp_project/erp_root/urls.py`
- `ZCHPC-ERP/zchpc-erp-synergy-main/src/App.tsx`
- `ZCHPC-ERP/employee-portal/src/App.tsx`
- `DevOps_and_Infrastructure/ZCHPC-ERP-2026-10-19-unresolved-merge-conflicts.md`

---

**Completed By:** Copilot
**Duration:** One orientation pass
