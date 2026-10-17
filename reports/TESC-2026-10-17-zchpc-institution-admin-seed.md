# TESC ZCHPC institution administrator seed

**Date:** 2026-10-17
**Project:** TESC
**Type:** Account Provisioning
**Status:** Completed

## Summary
Seeded the requested institution administrator account in production for
ZCHPC, matching the existing staging profile: tenant-scoped Full
Administrator, 29 permissions, staff access, and no global superuser access.

## Context / Trigger
The user requested a production institution-side account for
`tinotendamupezeni@thuthuka.tech` under the ZCHPC institution.

## Scope
Included the production user record, ZCHPC institution association, role
assignment, password hash, account flags, and institution login verification.
No global users, institution records, permissions, or application images were
changed.

## Method
Inspected staging and production first. Staging contained the target profile
as a tenant-scoped `Full Administrator` for institution `ZCHPC`, with 29
permissions, `is_staff=True`, `is_superuser=False`, and
`must_change_password=False`. Production already had the matching ZCHPC role
and permission set, so the user was created directly against those records.

## Decisions & Findings
- Production ZCHPC is institution ID 21.
- The production `Full Administrator` role for ZCHPC contains all 29 staging
  permissions.
- The account was not present in production and was created as user ID 360.
- The institution login endpoint requires an explicit institution selection;
  login succeeded when `institution_id=21` was supplied.

## Changes Made
- Created `tinotendamupezeni@thuthuka.tech`.
- Set the display name to Tinotenda Mupezeni.
- Linked the user directly to institution ZCHPC.
- Assigned the ZCHPC `Full Administrator` role.
- Set staff access, kept global superuser access disabled, and activated the
  account.
- Set `must_change_password=False` to match staging.

## Verification
- Password hash verification succeeded.
- Account reports ZCHPC, Full Administrator, and 29 permissions.
- Production institution login returned HTTP 200 with:
  `institution_id=21` and `message=Login successful`.
- Backend, worker, institution frontend, and nginx remained running with
  restart count zero.

## Follow-ups / Deferred
- Complete OTP verification if OTP enforcement is enabled for this account's
  production login flow.
- Rotate or change the initial password after first sign-in according to the
  account-owner policy.

## References
- Production `users.CustomUser`
- Production `users.Role`
- Production `academic.Institution`
- Production endpoint `/api/instauth/login/`

---

**Completed By:** Copilot
**Duration:** Same session
