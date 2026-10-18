# User Role Option Scope Fix

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Type:** Bug Fix / Contract Integrity / UI Authorization Boundary
**Status:** Completed in staging

## Summary

Corrected the main user creation dialog so a global system administrator sees
only global roles and departments, with duplicate labels removed. This aligns
the frontend choices with the backend tenant-scope validation that was already
rejecting institution-scoped roles.

## Context / Trigger

Staging user creation returned `System users can only assign global roles`.
The form displayed many identical `Full Administrator` entries because it
passed all institution and global roles into the modal.

## Scope

Included the main settings page's user modal inputs and staging frontend
deployment. Excluded database role cleanup, backend authorization changes, and
production.

## Method

Inspected the staging database role scopes, confirmed the actor was a global
superuser, traced the page-to-modal props, filtered options by active scope,
deduplicated labels, built the frontend, and verified the live staging asset
and route.

## Decisions & Findings

- Backend rejection was correct and was preserved.
- The UI contract was wrong because it exposed unassignable choices.
- Duplicate `Full Administrator` records are institution-specific roles with
  the same name; they were not duplicate rendering artifacts.

## Changes Made

- `frontend/src/pages/Settings.tsx`
  - Filters roles and departments by `main` versus `institutions` scope.
  - Removes duplicate labels before passing options to `UserModal`.
- `frontend/src/modules/settings/Users.tsx`
  - Hides `Add User` outside the main scope because the global endpoint cannot
    create institution-scoped users.
- Deployed frontend image:
  `tinotenda762/tesc-main:user-options-4fdbcde`.

## Verification

- Frontend production build passed.
- Live staging asset changed to `/assets/index-bYi5_bmw.js`.
- Live bundle no longer contains the old `Default Password` UI.
- `/settings` returned HTTP 200.
- Frontend container restart count after deployment: 0.
- The live main-scope user list keeps the Add User control; the institution
  scope does not expose it.

## Follow-ups / Deferred

- Retry creating `massala.care@gmail.com` using the single global
  `Full Administrator` entry.
- Add automated frontend modal coverage for scope filtering.
- Improve institution-scope labels with institution names if that workflow is
  intentionally supported from this page.

## References

- `Frontend_and_UI/TESC-2026-10-18-user-role-options-cross-scope-duplicates.md`
- `frontend/src/pages/Settings.tsx`
- `frontend/src/modules/settings/UserModal.tsx`
- `backend/users/serializers/settings_serializers.py`

---

**Completed By:** Copilot
**Duration:** One staging fix session
