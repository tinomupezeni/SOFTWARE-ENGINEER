# User Create Selected Mixed-Scope Role

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Environment:** Staging and source
**Severity:** High
**Status:** Resolved

## Summary

The main user dialog displayed scope-filtered global roles, but its submit
handler looked up the selected role name in the original mixed role array.
Institution-specific records with the same name could therefore be submitted,
causing the backend to correctly reject the request even though the visible
option appeared valid.

## Symptoms

- The dialog showed one global `Full Administrator` option.
- Creating a user returned:
  `System users can only assign global roles.`
- Staging nginx recorded a 58-byte validation response.

## Environment Details

- **Server/Host:** Staging VM `10.50.1.37`
- **Services Affected:** Main TESC user creation
- **Related Components:** `frontend/src/pages/Settings.tsx`,
  `backend/users/serializers/settings_serializers.py`
- **Time First Observed:** 2026-10-18 09:34 CAT

## Investigation Steps

### 1. Initial Diagnosis

Confirmed staging contains one global `Full Administrator` role and many
institution-specific roles with the same name. Compared the modal options with
the payload construction in `saveUser()`.

### 2. Root Cause Analysis

The modal received `userRoleOptions`, but `saveUser()` used:

```ts
roles.find((r) => r.name === newUser.role)
```

The first same-named role in the mixed array could be institution-scoped.

### 3. Key Findings

- Backend authorization was working correctly.
- Filtering only the rendered options was insufficient.
- The submit handler must resolve IDs from the same filtered set used to render
  the control.

## Root Cause

The frontend had two divergent role-selection contracts: the display path used
scope-filtered options while the submission path used the unfiltered catalog.

## Prevention / Rule

**Guardrail:** The value-to-ID lookup used during submission must use the exact
same filtered option collection passed to the select control.

This prevents duplicate labels across scopes from turning a valid visible
choice into an invalid submitted foreign ID.

## Solution

### Immediate Fix

Updated `saveUser()` to resolve both role and department IDs from the
scope-filtered, deduplicated main options.

### Long-term Fix

Use IDs as select values rather than names, and add frontend contract coverage
for duplicate labels across institution scopes.

## Prevention

- [x] Align submit lookup with rendered options
- [x] Preserve backend scope validation
- [ ] Use role/department IDs as select values
- [ ] Add automated frontend duplicate-label coverage

## References

- `frontend/src/pages/Settings.tsx`
- `frontend/src/modules/settings/UserModal.tsx`
- `backend/users/serializers/settings_serializers.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same-day staging fix
