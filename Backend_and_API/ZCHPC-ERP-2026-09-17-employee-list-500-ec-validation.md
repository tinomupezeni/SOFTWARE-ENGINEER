# API 500 Error: Domain Validation Fails for Actual ZCHPC Employee IDs (EC Numbers)

**Date:** 2026-09-17
**Project:** ZCHPC-ERP
**Environment:** Production (erp-vm)
**Severity:** High (Broken Employee Listing)
**Status:** Resolved

## Summary
After seeding the system with actual ZCHPC employee records, the frontend `EmployeeList` component displayed "0 active records", although the dashboard correctly counted 28 employees. The root cause was a 500 Internal Server Error thrown by the backend when fetching the list of employees. 

## Symptoms
- Employee list endpoint `GET /api/v2/hr/employees/` returned a 500 error.
- The stack trace showed `shared.domain.exceptions.domain_exceptions.ValidationError: Invalid Employee ID format: H021. Expected format: EMP0001 or UUID`.

## Root Cause
The `EmployeeId` domain value object had a strict regex validation rule (`^EMP(\d{4,6})$`) expecting legacy placeholder formats (e.g. `EMP0001`). However, actual ZCHPC employee EC numbers follow a different alphanumeric format (e.g., `H021`, `H060`). When the ORM fetched the real data, the domain layer rejected it upon hydration into the `EmployeeId` value object, crashing the endpoint.

## Solution
1. Updated the regex pattern in `erp_project/src/shared/domain/value_objects/employee_id.py` to `^[A-Z0-9\-]{2,20}$` to safely encompass real ZCHPC EC numbers.
2. Updated the `numeric_part` property extraction logic to use `re.search(r'\d+', self.value)` to prevent regex capture group errors.
3. Rebuilt and recreated the `zchpc_api` docker container to apply the fix.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/Data changes required (Domain Value Object rules relaxed)

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
