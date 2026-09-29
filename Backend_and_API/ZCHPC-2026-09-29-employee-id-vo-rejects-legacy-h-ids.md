# Employee list empty on prod: EmployeeId VO rejected legacy H staff IDs

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Environment:** Production (admin frontend + `/api/v2/hr/employees/`)
**Severity:** Critical
**Status:** Resolved

## Summary

Employee Management showed "0 active records / No employees found" with
34 active rows in the DB. One legacy `H059`-style row failed the
`EmployeeId` value-object validation during repository mapping, raising
for the **entire list** (HTTP 500); the frontend caught it into
`console.error` and rendered the empty state. Fixed by accepting the
institutional `H###` format in the VO (27 of 34 prod rows carry it) and
giving the UI an honest error state. Verified end to end: 34/34 rows.

## Symptoms

- Admin → HR → Employee Management: "0 active records", "No employees
  found. Try adjusting your search filters." with empty search + All
  Departments.
- No visible error; failure only in browser console.

## Environment Details

- **Server/Host:** erp-vm prod (`zchpc_api` + `zchpc_db`)
- **Services Affected:** `GET /api/v2/hr/employees/` (500), admin
  `Employees.tsx`
- **Related Components:** `EmployeeId` VO, `DjangoEmployeeRepository._to_entity`,
  `EmployeeListCreateView`, admin `Employees.tsx`
- **Time First Observed:** 2026-09-29 (tester screenshot during test phase)

## Investigation Steps

### 1. Initial Diagnosis

DB check: 34/34 rows `is_active=true` — data present. Read the view
(`EmployeeListCreateView.get` → `service.get_active_employees()` →
serializer) and the frontend (`.catch(error => console.error(...))`
leaving `[]` → empty state). So either the call failed or the shape was
wrong — with the error swallowed, the UI couldn't tell.

### 2. Root Cause Analysis

Ran the service path in prod Django shell:

```
shared...ValidationError: Invalid Employee ID format: H059.
Expected format: EMP0001 or UUID
```

raised in `employee_repository._to_entity` → `EmployeeId(...)`.
`hr_employees.employee_id NOT LIKE 'EMP%'` → 27 rows (`H059`, `H074`,
…). First bad row aborts the whole list comprehension → view 500s.

### 3. Key Findings

- The H IDs are genuine ZCHPC staff numbers from spreadsheet imports —
  renaming them to EMP format would destroy institutional identity.
- ID generation (`get_max_employee_id`) only scans `EMP%` rows, so
  widening the VO can't collide with sequencing.
- The empty-state copy actively misled ("try adjusting filters").

## Root Cause

Strict write-time validation applied on the read path: a value object
that only knew `EMP`+UUID met 27 legacy institutional IDs and failed
closed over the entire collection instead of one row.

## Prevention / Rule

**Guardrail:** any repository `_to_entity`/`_to_dto` collection mapping
must be covered by a test that round-trips the *actual production ID
formats* (seed the test with legacy rows), and list views must be
exercised against a non-empty realistic DB — the pre-existing unit suite
passed because no test ever fed an H ID through the VO.

## Solution

### Immediate Fix

- `EmployeeId` accepts `^H\d{2,6}$` (normalized uppercase, `numeric_part`
  0 like UUIDs; `generate`/`from_number` still EMP-only). 4 new unit
  tests, 69 pass. PR #35, merged `9eb49f3`.
- `Employees.tsx`: `loadError` state with status-aware message + Retry
  instead of silent empty list.

### Long-term Fix

- Audit other VOs applied on read paths for the same fail-closed shape
  (`NationalId`, etc.) against real prod value distributions.

## Prevention

- [x] Code changes required (VO + UI + tests, PR #35)
- [ ] VO audit for other strict-on-read validations
- [ ] Frontend rule: no `.catch` that only logs on data-loading paths

## Related Issues

- Staging schema drift found during verification:
  `DevOps_and_Infrastructure/ZCHPC-2026-09-29-staging-db-schema-drift.md`
- Honest-error-state work matches the design-refresh voice work
  (`statusConfig.ts` precedent).

## References

- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/35

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** ~1.5h (incl. staging DB rebuild + e2e proofs)
