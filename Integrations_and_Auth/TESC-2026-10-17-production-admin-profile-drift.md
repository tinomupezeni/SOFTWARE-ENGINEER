# Production admin profile drift

**Date:** 2026-10-17
**Project:** TESC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The production `mupezeni2001@gmail.com` account did not match the same
full-administration profile used in staging. Although the account had the
expected department name, it had no effective role permissions and was not
marked as staff or superuser.

## Symptoms
- Production user `mupezeni2001@gmail.com` had a migrated role with zero
  permissions.
- `is_staff` and `is_superuser` were both false.
- Staging had the same user as a `System Admin` with 29 permissions and both
  administrative flags enabled.

## Environment Details
- **Server/Host:** Production VM `10.50.200.35`
- **Services Affected:** Main TESC authorization and administration
- **Related Components:** `CustomUser`, `Role`, `Permission`
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Compared the user record, role, department, flags, and role permission set
between staging and production.

### 2. Root Cause Analysis
The production account had been provisioned with an existing migrated role,
while the shared production `System Admin` role contained no permissions.
Staging and production had drifted in both role assignment and administrative
flags.

### 3. Key Findings
- Staging target: `System Admin`, department `Innovation and
  industrialisation`, 29 permissions, staff and superuser enabled.
- Production initially: migrated role, zero permissions, staff and superuser
  disabled.
- All 29 staging permission codenames existed in production and could be
  synchronized without schema changes.

## Root Cause
Role and user authorization data was not included in the image promotion or
configuration parity checks, allowing production database state to diverge
from staging.

## Prevention / Rule
**Guardrail:** Add a non-secret authorization parity check for designated
seed/admin accounts that compares role name, administrative flags, department,
and permission codenames across staging and production before release.

This catches database-resident access drift that cannot be detected by Docker
image or environment-variable verification.

## Solution

### Immediate Fix
Assigned the production user to `System Admin`, enabled staff and superuser
access, preserved the department and account identity, and synchronized the
role’s 29 permissions from staging.

### Long-term Fix
Manage seed/admin profile expectations as versioned deployment data or an
audited provisioning command, and add authorization parity checks to the
release gate.

## Prevention
- [x] Configuration/data changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## References
- Production `users.CustomUser` and `users.Role`
- Staging `System Admin` role
- TESC production admin profile remediation report

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
