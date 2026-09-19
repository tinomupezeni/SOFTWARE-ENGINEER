# API 404 Error: BFF Employee Profile Endpoint Rejects Numeric IDs

**Date:** 2026-09-17
**Project:** ZCHPC-ERP
**Environment:** Production (erp-vm)
**Severity:** High (Broken Employee Profiles)
**Status:** Resolved

## Summary
When users attempted to view or edit an employee's detailed information, the frontend requested `/api/v2/bff/employees/{id}/` resulting in a 404 Not Found error.

## Symptoms
- Network requests to `/api/v2/bff/employees/56/` and `/api/v2/bff/employees/3/` returned HTTP 404.
- The UI failed to load the employee's full profile information.

## Root Cause
The Django `urls.py` in the `bff` (Backend-For-Frontend) module expected a strictly formatted UUID: `path("employees/<uuid:uuid>/", ...)`. However, the frontend passes the numeric `id` of the `Employee` model (e.g. 56 or 3). Because the regex for `<uuid:uuid>` failed to match integers, Django's URL resolver threw a 404.

## Solution
1. Updated `erp_project/src/modules/bff/api/urls.py` to accept any string format: `path("employees/<str:identifier>/", ...)`.
2. Modified the backend view `BFFEmployeeDetailView` to accept `identifier` instead of `uuid`.
3. Upgraded `EmployeeOrchestrator.get_full_profile()` to be polymorphic: it attempts to parse the identifier as a UUID first; if it fails, it checks if it's an integer (`id`); and otherwise queries it as an `employee_id`. 
4. Rebuilt and recreated the `zchpc_api` docker container to deploy the changes.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/Data changes required (URL router and orchestrator updated)

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
