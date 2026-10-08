# Studio Sidebar Hidden By RBAC Filter

**Date:** 2026-10-08
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The "Intelligence Studio" link was missing from the sidebar in the client frontend application because it was being filtered out by the Role-Based Access Control (RBAC) link filtering logic for users without explicit permissions.

## Symptoms
- The user could not see the "Intelligence Studio" navigation item in the "Analysis" section of the sidebar, even though it was defined in the `AppSidebar.tsx` navigation array.

## Environment Details
- **Server/Host:** Staging VM (10.50.1.37)
- **Services Affected:** `frontend_client`
- **Related Components:** `frontend/src/components/layout/AppSidebar.tsx`
- **Time First Observed:** 2026-10-08

## Investigation Steps

### 1. Initial Diagnosis
Checked `inst/src/components/layout/AppSidebar.tsx` thinking the user was looking at the admin app, but realized the provided sidebar list matched the `frontend_client` application exactly.

### 2. Root Cause Analysis
Reviewed `frontend/src/components/layout/AppSidebar.tsx` and observed that the `filterLinks` function removes any navigation item whose URL is not explicitly in `userPermissions` or in a hardcoded list of bypass URLs (like `/dashboard`, `/help`, `/settings`).

### 3. Key Findings
- The new `/studio` endpoint was added to the `admissionsCategory` array.
- However, `/studio` was not added to the `filterLinks` bypass array and standard users don't have this permission configured yet, so it was hidden.

## Root Cause
The sidebar navigation menu relies on an explicit allowlist or database permission for visibility. The newly added feature was not granted to all users nor added to the global allowlist.

## Prevention / Rule
**Guardrail:** When adding new globally accessible or beta pages, add their paths to the standard RBAC-bypass list or ensure database permissions are granted during deployment.

This ensures new features are discoverable during user testing phases before granular permissions are assigned.

## Solution

### Immediate Fix
Added `/studio` to the bypass array in `frontend/src/components/layout/AppSidebar.tsx`.

```typescript
// Changed:
if (["/dashboard", "/help", "/settings"].includes(item.url)) return true;
// To:
if (["/dashboard", "/help", "/settings", "/studio"].includes(item.url)) return true;
```

Committed the fix and pushed to the `staging` branch, then ran `deploy_staging.sh` on the staging VM.

### Long-term Fix
When granular permissions for the Intelligence Studio are finalized, `/studio` should be removed from the bypass list and instead granted explicitly via the user's roles.

## Prevention
- [ ] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 15m
