# TESC Department Duplication Investigation

**Date:** 2026-10-17  
**Project:** TESC  
**Type:** Audit / Data Integrity Investigation  
**Status:** Completed investigation; remediation deferred

## Summary

Investigated duplicate department entries visible under TESC main Settings.
The issue is confirmed in both staging and production: the main system has
17 global department rows, including two exact global `Administration` rows.
The older row is active and assigned to three users; the newer row is unused
and has a different permission list. No records or code were changed.

## Context / Trigger

The user reported duplicate department names and requested an explanation
only, explicitly asking that the issue not be fixed during this investigation.

## Scope

Included:

- Department model and database uniqueness behavior.
- Department API queryset and serializer behavior.
- Main Settings frontend filtering and rendering.
- Seed commands and permission migration history.
- Read-only live comparison of staging and production department data.

Excluded:

- Deleting, merging, renaming, or reassigning departments.
- Changing permissions or user roles.
- Code or migration changes in TESC.
- Production or staging service restarts.

## Method

Traced the frontend request path, inspected the Django model/API and seed
paths, reviewed migration history, and ran read-only PostgreSQL queries inside
the staging and production database containers. The live queries compared
department IDs, names, institution scope, permissions, creation time, and
user assignments.

## Decisions & Findings

1. The displayed list is the global (`institution IS NULL`) scope. The UI
   fetches all departments and filters out institution-linked records for the
   Main System tab.
2. The database has an exact duplicate:
   - ID 5: `Administration`, no modules, created 2026-06-12, three users.
   - ID 152: `Administration`, two modules, created 2026-06-16, zero users.
3. Staging and production contain the same rows and timestamps for the global
   department set, so the duplication is shared data state rather than a
   staging-only frontend cache issue.
4. The model's `unique_together = ('institution', 'name')` does not prevent
   case-only variants and does not provide a canonical global department
   registry.
5. The settings page renders each returned database row independently; it
   does not deduplicate by normalized name or explain record identity.
6. The likely creation pattern is historical/separate seeding and manual/API
   creation: the admin seeder creates `Administration`, while the later
   global department rows were created in a separate batch on 2026-06-16.
   The exact originating request for ID 152 is not recoverable from the
   department model because it has no creator/audit foreign key.

## Changes Made

No TESC code or data changes were made. This investigation produced only the
engineering issue log and report in the separate
`SOFTWARE-ENGINEER` repository.

## Verification

- Read-only staging and production container inspection succeeded.
- Both databases returned the same 17 global department rows.
- Both databases returned the same exact duplicate pair, IDs 5 and 152.
- Staging assignment query confirmed three users on ID 5 and zero users on
  ID 152.
- Local Django inspection and source tracing matched the live behavior.

## Follow-ups / Deferred

- Establish the canonical global department list with the product owner.
- Reconcile duplicate/case-variant rows while preserving user assignments and
  permission intent.
- Add a case-insensitive scoped uniqueness constraint after cleanup.
- Route seed/import/manual creation through one scoped idempotent service.
- Add creator/audit metadata for future department changes.
- Improve the UI to show scope and distinguish records during cleanup.

## References

- `backend/users/models.py`
- `backend/users/views/settings_views.py`
- `backend/users/management/commands/seed_admin.py`
- `backend/users/management/commands/seed_departments.py`
- `backend/users/migrations/0004_migrate_department_permissions.py`
- `frontend/src/pages/Settings.tsx`
- `frontend/src/services/settings.services.ts`
- `SOFTWARE-ENGINEER/Database_and_State/TESC-2026-10-17-duplicate-global-departments.md`

---

**Completed By:** Copilot  
**Duration:** One investigation session
