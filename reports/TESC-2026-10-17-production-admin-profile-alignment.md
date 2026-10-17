# TESC production admin profile alignment

**Date:** 2026-10-17
**Project:** TESC
**Type:** Access Provisioning / Configuration Remediation
**Status:** Completed

## Summary
Aligned the production `mupezeni2001@gmail.com` account with its staging
profile as a full System Admin for the Innovation and industrialisation
department.

## Context / Trigger
The user requested that the production account receive the same full
administration profile as the corresponding staging account.

## Scope
Included comparison and synchronization of account flags, role, department,
and role permissions. Password, email, username, institution, and person
identity were not changed.

## Method
Inspected both environments through Django management shells, compared the
staging role’s permission codenames with production’s permission catalog,
validated that all required permissions existed, applied the profile, and
verified representative effective permissions and the public OTP login path.

## Decisions & Findings
- Staging profile is global `System Admin`.
- The staging role has 29 permissions covering users, students, staff,
  institutions, faculties, programs, payments, reports, audit, settings, and
  role management.
- Production already had a global `System Admin` role but it was empty and
  shared by the existing admin account.
- The shared role was synchronized to staging’s 29-permission set, so both
  accounts using it now have the same full-admin role.

## Changes Made
- Production user `mupezeni2001@gmail.com`:
  - Assigned `System Admin`.
  - Kept department `Innovation and industrialisation`.
  - Set `is_staff=True`.
  - Set `is_superuser=True`.
  - Kept account active and `must_change_password=False`.
- Synchronized all 29 staging permission codenames to the production
  `System Admin` role.

## Verification
- Production user reports `System Admin`, 29 permissions, staff and superuser
  enabled, and the expected department.
- Representative permissions including `audit.view`, `institution.edit`,
  `student.bulk_upload`, `user.delete`, and `role.edit` evaluate true.
- Public password login returned HTTP 200 and reached `requires_otp: true`.
- Backend and Celery worker remained running with restart count zero.

## Follow-ups / Deferred
- Add authorization-profile parity checks to the deployment gate.
- Review whether the shared `System Admin` role should remain shared or be
  replaced with explicitly scoped roles for separate administrators.

## References
- Production admin profile drift issue log
- `backend/users/models.py`
- TESC main login endpoint `/api/users/token/`

---

**Completed By:** Copilot
**Duration:** Same session
