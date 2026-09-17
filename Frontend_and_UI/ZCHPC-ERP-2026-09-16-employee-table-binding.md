# Employee Table Missing Position and Department

**Date:** 2026-09-16
**Project:** ZCHPC-ERP
**Environment:** Production (erp-vm)
**Severity:** Low
**Status:** Resolved

## Summary
The employee listing table in the `HR/employees/EmployeeList.tsx` frontend component displayed "Unassigned" and "-" for employees' departments and positions, even though the database and API correctly contained this data.

## Symptoms
- The frontend displayed "Unassigned" under the Department column and "-" under the Position column in the HR Employee List table.
- The `zchpc_api` backend correctly mapped and returned `department_name` and `position_title` in the `EmployeeDTO`.

## Environment Details
- **Server/Host:** `erp-vm`
- **Services Affected:** `zchpc_frontend` (`EmployeeList.tsx`), `zchpc_api` (`employee_serializers.py`)
- **Time First Observed:** 2026-09-16

## Investigation Steps

### 1. Root Cause Analysis
- The frontend `EmployeeList.tsx` component was attempting to render `{employee.position}` and `{employee.department}`.
- However, the `GET /api/v2/hr/employees/` endpoint (powered by `EmployeeListItemSerializer`) serialized these fields as `department_name` and `position_title`, leading to a mismatch between the expected JSON keys on the frontend and the actual API response keys.

## Root Cause
A property name mismatch between the frontend React component and the backend API serializer mapping for nested foreign key string representations.

## Solution

### Immediate Fix
1. Updated `EmployeeListItemSerializer` in the backend to include `department` and `position` properties as aliases for `department_name` and `position_title` to maintain backward compatibility.
2. Updated `EmployeeList.tsx` in the frontend to preferentially check `employee.position_title` and `employee.department_name` while falling back to the original keys.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/Data changes required (Frontend & API bindings updated)

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
