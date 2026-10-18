# Massala Staging User Removal

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Type:** Data Cleanup / Staging Test Preparation
**Status:** Completed

## Summary

Removed only staging user ID `224` for `massala.care@gmail.com` so the main
TESC onboarding flow can be tested with that address. The account was
institution-scoped to ZCHPC, had no staff, student, or institution-admin
dependency, and was deleted transactionally after an exact identity guard.

## Context / Trigger

The address was rejected as already used when testing main-portal onboarding,
but the matching record was hidden from the main/global user list because it
belonged to the ZCHPC institution scope.

## Scope

Included the single staging user record and its direct audit references.
Excluded production, other staging users, role records, department records,
institution records, and application code.

## Method

Ran a read-only dependency preflight, created a targeted data-only rollback
dump, deleted the exact record inside a transaction, and verified identifier
availability and remaining audit references.

## Decisions & Findings

- Exact target: user ID `224`.
- Exact identifiers: email and username `massala.care@gmail.com`.
- Scope: institution ID `21`, ZCHPC.
- No staff profile, student profile, or institution-admin record existed.
- The user had two audit records; deletion preserved those audit rows with a
  null user reference.
- No production data was inspected or modified.

## Changes Made

- Deleted staging `users_customuser` record ID `224`.
- Preserved the targeted rollback dump at container-local path
  `/tmp/massala-delete-preflight.sql` on `tesc-db-1`, SHA-256:
  `8f507bf41bf3e163e4a3e15d2f3da7f27c6cca87c6ffa4308c1a2568cad08882`.

## Verification

- Email match count after deletion: zero.
- Username match count after deletion: zero.
- Remaining audit rows referencing user ID `224`: zero.
- Database services remained running; no service recreation or restart was
  performed.

## Follow-ups / Deferred

- Recreate the account through the main TESC staging flow.
- Verify the invitation email, forced password change, and subsequent login.
- Improve the duplicate error to explain hidden institution-scoped conflicts;
  this remains tracked separately.

## References

- `Integrations_and_Auth/TESC-2026-10-18-institution-user-hidden-from-main-list.md`
- `reports/TESC-2026-10-18-massala-account-scope-investigation.md`

---

**Completed By:** Copilot
**Duration:** One staging operation
