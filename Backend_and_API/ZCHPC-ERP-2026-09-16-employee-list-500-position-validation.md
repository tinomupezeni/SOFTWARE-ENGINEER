# Employee List 500 Error due to Position Validation

**Date:** 2026-09-16
**Project:** ZCHPC-ERP
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
The employee list endpoint (`/api/v2/hr/employees/`) crashed with a 500 Internal Server Error when fetching the list of employees. This happened because some `Position` records in the database did not have a `department` assigned, which caused a domain validation error when mapping the database models to the domain entities.

## Symptoms
- The frontend displayed an empty list (or crashed/showed no data) at `/hr/hr-employees`.
- The backend threw `shared.domain.exceptions.domain_exceptions.ValidationError: Department is required for a position` during the `GET /api/v2/hr/employees/` request.

## Environment Details
- **Server/Host:** `erp-vm`
- **Services Affected:** `zchpc_api`
- **Related Components:** `Position` domain entity, `Position` Django model
- **Time First Observed:** 2026-09-16

## Investigation Steps

### 1. Initial Diagnosis
The database confirmed that 50 employees existed, but the frontend was not displaying any of them. A test using the Django `APIClient` revealed that the endpoint was returning a 500 error instead of the JSON list.

### 2. Root Cause Analysis
- The stack trace indicated a crash in `_to_dto` inside the `employee_service.py` when attempting to fetch the position.
- The `Position` Django model allows `department` to be null (`null=True, blank=True`).
- However, the Domain-Driven Design (DDD) entity for `Position` (`src/modules/hr/domain/entities/position.py`) strictly validates that `department_id` is provided in its `_validate` method.
- Seeded positions were created without departments, triggering this validation error when loaded from the database.

## Root Cause
A mismatch between the Django ORM schema (which allows null departments on positions) and the strict Domain Entity validation (which requires a department). Database records with null departments crash the application when read.

## Prevention / Rule
**Guardrail:** Align database schema constraints with domain entity validation rules. If a domain entity strictly requires a field, the corresponding Django model should enforce `null=False` (or at least, all application logic and seed scripts must ensure it is populated).

## Solution

### Immediate Fix
Updated the database records to ensure every `Position` has a valid `department` assigned. This stopped the domain validation error and allowed the API to successfully serialize and return the list of employees.

### Long-term Fix
Update the `Position` Django model to enforce `null=False` for the `department` field if it is fundamentally required by the domain logic.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/Data changes required (Data updated)

## Related Issues
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 5 minutes
