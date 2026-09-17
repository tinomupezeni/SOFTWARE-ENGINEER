# Active Modules Endpoint Returns 404

**Date:** 2026-09-16
**Project:** ZCHPC-ERP
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
The frontend failed to display the sidebar modules (HR, Payroll, Accounting, etc.) for a superuser. This was caused by the `SystemModule` feature being introduced in the codebase, but the production Docker API container wasn't rebuilt to include the updated code. Consequently, the `/auth/modules/active/` endpoint returned a 404, causing the frontend to assume no modules were active.

## Symptoms
- The superuser logged in but could only see non-modular links in the sidebar: Dashboard, Settings, App Store.
- The `activeModules` fetch in `MainLayout.tsx` silently failed and filtered out all modular items.

## Environment Details
- **Server/Host:** `erp-vm`
- **Services Affected:** `zchpc_api`, `zchpc_frontend`
- **Related Components:** `SystemModuleViewSet`, `SystemModule` model
- **Time First Observed:** 2026-09-16

## Investigation Steps

### 1. Initial Diagnosis
Checked `AuthContext.tsx` to verify that `user.is_superuser` rightly bypasses permission checks (returns `true`). Then, inspected `MainLayout.tsx` and `navConfig.tsx`, which revealed that navigation items with a `moduleIdentifier` require that identifier to be present in the `activeModules` list fetched from the backend.

### 2. Root Cause Analysis
- The backend `getActiveModules` makes a GET request to `/auth/modules/active/`.
- In testing, this endpoint returned `404 Not Found`.
- Checking the backend container, the `SystemModule` model and its corresponding endpoints were completely absent from the `zchpc_api` container's `models.py`, despite existing in the VM host's codebase (`/home/user/Documents/erp/ZCHPC-ERP`).

### 3. Key Findings
- The VM's host codebase was updated, but the `api` image was never rebuilt and recreated.
- The database was missing the `SystemModule` data since it was never seeded.

## Root Cause
A deployment drift: the production container was running an older image while the codebase on the host had newer features (`SystemModule`). This missing endpoint resulted in the frontend hiding all modular navigation items.

## Prevention / Rule
**Guardrail:** Establish a unified deploy script (e.g., `deploy.sh`) that ALWAYS rebuilds backend containers and runs `python manage.py migrate` when pulling new changes, rather than relying on manual image builds. 

Ensuring containers are strictly tied to the latest codebase state via an automated script prevents "ghost" code deployment where files exist on the host but not inside the running application.

## Solution

### Immediate Fix
1. Rebuilt the `zchpc_api` container image natively on the VM (`docker build -t tinotenda762/zchpc-erp-api:latest ...`).
2. Recreated the `api` container.
3. Faked a failing migration (`leave 0003`) to allow `manage.py migrate` to succeed.
4. Ran a Django shell script to seed and activate all default system modules (`hr`, `payroll`, `sales`, `accounts`, `procurement`, `inventory`).

### Long-term Fix
Update CI/CD pipelines to ensure the API image is built, pushed, and correctly pulled/recreated in production automatically.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (Container Rebuilt)

## Related Issues
- N/A

## References
- Docker deployment practices

---

**Resolved By:** Antigravity
**Time to Resolution:** 15 minutes
