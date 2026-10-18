# User Role Options Cross-Scope Duplicates

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Environment:** Staging
**Severity:** High
**Status:** Resolved in source; staging deployment pending

## Summary

The main user dialog received the complete roles and departments arrays even
when the administrator was creating a global user. The UI therefore displayed
one `Full Administrator` option for every institution, while the backend
correctly rejected institution-scoped role IDs for a global system user.

## Symptoms

- User creation returned HTTP 400 with:
  `System users can only assign global roles.`
- The role dropdown displayed many identical `Full Administrator` entries.
- The department dropdown could likewise display repeated names from multiple
  institutions.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** Main TESC user-management UI
- **Related Components:** `frontend/src/pages/Settings.tsx`,
  `frontend/src/modules/settings/UserModal.tsx`,
  `backend/users/serializers/settings_serializers.py`
- **Time First Observed:** 2026-10-18 09:22 CAT

## Investigation Steps

### 1. Initial Diagnosis

Inspected the live role data and the current system administrator scope. The
actor was a global superuser, while the database contained 29 institution-
scoped `Full Administrator` roles and one global role.

### 2. Root Cause Analysis

The settings page already filtered roles for its management list, but passed
the unfiltered `roles` and `departments` arrays into `UserModal`. The modal
used role names as values, so selecting a visually identical institution role
could resolve to an invalid ID for a global user.

### 3. Key Findings

- The backend scope rejection was correct and protected tenant boundaries.
- The frontend violated the backend contract by presenting invalid choices.
- Duplicate labels came from same-named records across institution scopes, not
  from duplicate HTML rendering.

## Root Cause

The user-create modal did not reuse the page's active scope filtering and
deduplication logic. It exposed all records returned by the administrative
listing endpoints, including records that the current actor could not assign.

## Prevention / Rule

**Guardrail:** User-create controls must receive only scope-filtered,
deduplicated role and department options, and their IDs must be validated by a
negative backend test.

This keeps the client choice set aligned with the authorization boundary
enforced by the API.

## Solution

### Immediate Fix

Filtered the user modal options by the active `main`/`institutions` scope and
deduplicated labels before rendering.

### Long-term Fix

Add UI contract coverage for global-user creation and improve institution-scope
labels when institution users are intentionally managed from the same screen.

## Prevention

- [x] Scope-filter user modal options
- [x] Deduplicate same-scope labels
- [x] Preserve backend negative authorization validation
- [ ] Add automated frontend modal coverage

## References

- `frontend/src/pages/Settings.tsx`
- `frontend/src/modules/settings/UserModal.tsx`
- `backend/users/serializers/settings_serializers.py`

---

**Resolved By:** Pending staging deployment
**Time to Resolution:** Investigation completed
