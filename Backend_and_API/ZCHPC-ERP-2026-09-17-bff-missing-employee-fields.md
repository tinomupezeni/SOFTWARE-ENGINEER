# BFF Endpoint Missing Extended Employee Profile Fields

**Date:** 2026-09-17
**Project:** ZCHPC-ERP
**Environment:** Production (erp-vm)
**Severity:** Medium (UI Missing Data)
**Status:** Resolved

## Summary
When viewing an employee profile in the `EmployeeDetailModal.tsx` frontend component, the National ID, Gender, Date of Birth, Marital Status, Position, and Department fields all displayed as blank (`--` or `No Position / No Dept`), despite this information existing in the backend database.

## Symptoms
- The UI modal lacked basic HR information that should have been populated.
- The `/api/v2/bff/employees/{id}/` endpoint did not include `national_id`, `department`, `department_id`, `position`, `position_id`, `date_of_birth`, `gender`, `marital_status`, and `is_active` in the JSON response payload.

## Root Cause
The `EmployeeOrchestrator` inside the `bff` module and the corresponding `UnifiedEmployeeProfileSerializer` were exclusively mapping base HR fields (`first_name`, `surname`, `email`, `phone`), Payroll fields, Bank Details, and Statutory Info. They were never updated to include the extended HR relational and personal fields required by the frontend's detailed view.

## Solution
1. Updated `erp_project/src/modules/bff/serializers/unified_employee.py` to declare all the missing serializers for the extended HR fields.
2. Updated `EmployeeOrchestrator.get_full_profile()` and `update_full_profile()` in `employee_orchestrator.py` to map these properties cleanly from the `Employees` domain model (handling `employee.department.name` mapping as well).
3. Resolved an indentation error during the fix.
4. Rebuilt and recreated the `zchpc_api` docker container to deploy the changes.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/Data changes required (BFF Serializer and Orchestrator payload updated)

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
