# Duplicate Global Departments in Main Settings

**Date:** 2026-10-17  
**Project:** TESC  
**Environment:** Staging and Production  
**Severity:** Medium  
**Status:** Workaround Applied

## Summary

The TESC main Settings page displays duplicate or near-duplicate global
departments because the database contains multiple global department records
with overlapping names, and the department model only enforces uniqueness on
`(institution, name)` using case-sensitive database equality. The exact
duplicate `Administration` records are global IDs 5 and 152 in both staging
and production.

## Symptoms

- Main System settings displays two `Administration` entries.
- Several department names differ only by case or wording, including
  `human resource` and `Human Resources`.
- The entries have different module-permission counts.
- The UI does not identify the record ID, creation source, or whether a
  same-named record is unused.

## Environment Details

- **Server/Host:** staging `10.50.1.37`; production `10.50.200.35`
- **Services Affected:** Django users API and TESC main Settings UI
- **Related Components:** `users.Department`, `DepartmentViewSet`,
  `Settings.tsx`, department seed commands and migrations
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis

The frontend was traced from `Settings.tsx` to
`fetchDepartments()` and `/api/users/departments/`. The UI fetches the full
department list, filters only by `institution` for the Main System tab, and
renders every returned record without name deduplication.

### 2. Root Cause Analysis

The model defines:

```python
unique_together = ('institution', 'name')
```

This permits one global and one institution-scoped department with the same
name, and it also permits case variants because the constraint is not
case-insensitive. The global list is additionally populated through more than
one path: the admin seeder creates `Administration`, while later department
creation/import activity can create additional records. The API does not
canonicalize or collapse those records.

### 3. Key Findings

- Staging and production contain the same 17 global department rows.
- Exact duplicate:
  - ID 5: `Administration`, 0 modules, created 2026-06-12, assigned to
    three users.
  - ID 152: `Administration`, 2 modules, created 2026-06-16, assigned to no
    users.
- The users assigned to ID 5 include the main admin and two other accounts.
- No users are assigned to ID 152, so the newer duplicate is currently
  unused.
- Both environments have the same duplicate pair, indicating the condition
  is in the shared data state rather than a frontend-only rendering defect.
- The department seeder uses `get_or_create(name=...)` without explicitly
  constraining `institution`, and the model/API allow repeated names under
  the same global scope because the database has no case-insensitive
  uniqueness guard.

## Root Cause

Department identity is not canonicalized at the database/API boundary.
Multiple creation paths can create global departments, while the uniqueness
constraint is case-sensitive and the settings UI renders all records as
independent choices. As a result, historical records, spelling/case variants,
and exact duplicate rows appear together.

## Prevention / Rule

**Guardrail:** Add a database-backed functional unique constraint on
`Lower(name)` within each institution scope, with an explicit null/global
scope strategy, and route all seed/import creation through one
`get_or_create` service that supplies the institution scope.

This directly prevents a second global `Administration` row and catches
case-only duplicates before they reach the UI. Existing data must be
reconciled before enabling the constraint.

## Solution

### Immediate Fix

The confirmed-unused duplicate global `Administration` row was removed from
both staging and production after a database backup and dependency preflight:

- Deleted `users_department.id=152`, guarded by `name='Administration'` and
  `institution_id IS NULL`.
- Verified zero users referenced the row before deletion.
- Verified the row was absent afterward and one global `Administration` row
  remained.
- Preserved the active row ID 5 and all its user assignments.
- No application services were restarted.

### Long-term Fix

- Decide the canonical department vocabulary and whether similarly named
  records represent distinct business units.
- Inventory and reconcile the remaining case/spelling variants and
  institution-scoped records.
- Preserve or migrate user assignments before removing unused duplicates.
- Add a safe uniqueness migration and tests.
- Improve the settings display with scope and record identity during the
  reconciliation period.

## Prevention

- [ ] Add case-insensitive scoped uniqueness after data cleanup
- [ ] Consolidate department creation paths
- [ ] Add duplicate-detection CI/data audit
- [ ] Add audit logging for department creation and edits
- [ ] Add a UI distinction between global and institution-scoped records

## Related Issues

- None created previously for this specific department duplication.

## References

- `backend/users/models.py:58-75`
- `backend/users/views/settings_views.py:45-105`
- `backend/users/management/commands/seed_admin.py:20-27`
- `backend/users/management/commands/seed_departments.py:25-27`
- `backend/users/migrations/0004_migrate_department_permissions.py`
- `frontend/src/pages/Settings.tsx:573-632`
- `frontend/src/services/settings.services.ts:15-24`

---

**Resolved By:** Not resolved; investigation recorded by Copilot  
**Time to Resolution:** Not applicable
