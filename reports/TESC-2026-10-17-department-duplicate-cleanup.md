# TESC Exact Department Duplicate Cleanup

**Date:** 2026-10-17  
**Project:** TESC  
**Type:** Database Cleanup / Data Integrity  
**Status:** Completed

## Summary

Removed only the confirmed-unused duplicate global `Administration` department
record, ID 152, from both staging and production. The cleanup was preceded by
database backups and a foreign-key/user-assignment preflight, and followed by
post-delete invariant checks. The active `Administration` row, ID 5, was
preserved.

## Context / Trigger

The main Settings page showed two global `Administration` rows. Investigation
identified ID 5 as active and assigned to users, while ID 152 had no user
assignments and represented the duplicate with a different permission list.
The user requested cleanup only after confirming no dependent records would be
affected.

## Scope

Included:

- Read-only dependency preflight in staging and production.
- Fresh custom-format PostgreSQL backups in both environments.
- Guarded deletion of only `users_department.id=152`.
- Post-delete duplicate, foreign-key, user-assignment, and service checks.

Excluded:

- Any rename, merge, permission change, or user reassignment.
- Case-only or spelling-variant department cleanup.
- Code, schema, migration, or frontend changes.
- Service restarts and deployment changes.

## Method

The preflight inspected PostgreSQL foreign keys referencing
`users_department`, queried the candidate's user assignments and permissions,
and verified the exact duplicate identity in both environments. Backups were
created with `pg_dump -Fc` and validated with `pg_restore --list`. Each delete
ran in a transaction with guards requiring exactly one global
`Administration` row at ID 152 and zero user assignments.

## Decisions & Findings

- Only `users_customuser.department_id` references `users_department` in the
  live schema.
- The candidate row had zero user assignments in both environments.
- The candidate had no separate permission table or many-to-many dependency;
  its permissions were stored inline in the row's JSON field.
- The active row ID 5 was not modified.
- The broader department normalization issue remains: case and wording
  variants still exist and require a separate canonicalization decision.

## Changes Made

Data-only changes:

- Staging: deleted global `users_department` ID 152.
- Production: deleted global `users_department` ID 152.

Backups:

- Staging:
  `/home/user/tesc_backups/tesc_db_pre_department_cleanup_20261017.dump`
  (18,591,535 bytes)
- Production:
  `/home/user/Documents/TESC-main/backups/tesc_db_pre_department_cleanup_20261017.dump`
  (27,337,422 bytes)

No TESC source files were changed.

## Verification

- Backup files were non-empty and passed `pg_restore --list`.
- Both deletes returned `BEGIN`, `DO`, `COMMIT`.
- Staging post-check:
  - candidate remaining: 0
  - global `Administration` rows: 1
  - user references to ID 152: 0
  - active ID 5 assignments: 3
  - department FK: `users_customuser.department_id`
- Production post-check:
  - candidate remaining: 0
  - global `Administration` rows: 1
  - user references to ID 152: 0
  - active ID 5 assignments: 2
  - department FK: `users_customuser.department_id`
- Staging and production containers remained running; no restart was needed.

## Follow-ups / Deferred

- Reconcile case/spelling variants such as `human resource`,
  `Human Resources`, and institution-scoped variants separately.
- Establish a canonical case-insensitive scoped uniqueness constraint only
  after the remaining data is reviewed.
- Add department creator/audit metadata so future duplicate origins are
  traceable.

## References

- `backend/users/models.py`
- `backend/users/views/settings_views.py`
- `frontend/src/pages/Settings.tsx`
- `SOFTWARE-ENGINEER/Database_and_State/TESC-2026-10-17-duplicate-global-departments.md`

---

**Completed By:** Copilot  
**Duration:** One cleanup session
