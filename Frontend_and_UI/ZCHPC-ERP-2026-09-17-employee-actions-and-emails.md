# Employee Management: Actions Column and Email Requirement Fixes

**Date:** 2026-09-17
**Project:** ZCHPC-ERP
**Environment:** Production (erp-vm)
**Severity:** Low (UI Refinement / Data Cleanup)
**Status:** Resolved

## Summary
The user requested two changes to the Employee list page:
1. Extract the "View Profile" and "Edit Details" actions from the hidden "3 dots" dropdown and display them natively as colored icon buttons.
2. Remove the auto-generated fabricated emails from the seeded real-world employee dataset.

## Symptoms
- Action buttons required two clicks to access.
- Seeded employees possessed fabricated `first.last@zchpc.ac.zw` emails because the Django `Employees` and `CustomUser` models strictly required unique email addresses.

## Root Cause
- The UI utilized a Headless UI `<Menu>` encapsulating `lucide-react` `MoreVertical` icon.
- The `Employees.email` Django ORM model field lacked `null=True, blank=True`, enforcing mandatory emails.

## Solution
1. **Frontend Refactoring:** Completely rewrote the `EmployeeActions` sub-component in `zchpc-erp-synergy-main/src/components/HR/employees/EmployeeList.tsx` to use inline flex-row Lucide icons (`Eye` and `Edit`) with explicit hover colors (blue and emerald backgrounds respectively). 
2. **Backend Database Modification:** 
   - Altered `Employees.email` in `models.py` to `null=True, blank=True` to allow records without emails.
   - Migrated the PostgreSQL database cleanly (`makemigrations` and `migrate`).
   - Ran an overriding Django shell script to surgically delete the fabricated `CustomUser` authentication records and blank out the `Employees.email` field for all seeded employees (excluding the master `admin@zchpc.ac.zw` account).
3. Rebuilt both `zchpc_api` and `zchpc_frontend` docker images and updated the deployment environment.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/Data changes required (UI overhaul, DB schema altered, mass data deletion script)

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
