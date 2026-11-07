# Staging does not contain the Inclusivity inline-edit update

**Date:** 2026-11-07
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Investigating

## Summary
The local `staging` branch contains the Inclusivity report inline-edit update,
but `tesc-inst-staging.zchpc.ac.zw` serves an older frontend bundle and does
not expose the new edit dialog. The feature is available in source and builds
successfully, but is not yet available on the staging URL.

## Symptoms
- Local commit `14ccc2c` adds the per-row pencil action and
  `EditInclusivityCategoryDialog`.
- The staging page returns the frontend bundle last modified on 2026-10-26.
- The staging bundle does not contain `Edit Inclusivity Category` or
  `Inclusivity category updated`.

## Environment Details
- **Server/Host:** `tesc-inst-staging.zchpc.ac.zw`
- **Services Affected:** Institution frontend
- **Related Components:** `inst/src/pages/Inclusivity.tsx`,
  `inst/src/components/EditInclusivityCategoryDialog.tsx`
- **Time First Observed:** 2026-11-07 18:25 +02:00

## Investigation Steps

### 1. Initial Diagnosis
Checked local history and the Inclusivity page implementation, then fetched
the staging route and its hashed JavaScript bundle.

### 2. Root Cause Analysis
The local feature commit is present on the `staging` branch, but the staging
host is serving an older static build. The staging artifact was not rebuilt
or promoted after the local change.

```bash
git show -s --format='%H %ad %s' --date=iso 14ccc2
curl -D - https://tesc-inst-staging.zchpc.ac.zw/dashboard/inclusivity
grep -F 'Edit Inclusivity Category' /tmp/tesc-inst-staging.js
```

### 3. Key Findings
- Local `inst/src/pages/Inclusivity.tsx` renders an edit action gated by
  `hasPermission("student.edit")`.
- The dialog saves through the existing `updateStudent` partial-update path.
- `npm run build` in `inst/` completed successfully.
- Staging returned HTTP 200 for the route but served no matching edit-dialog
  strings.

## Root Cause
Staging deployment artifact identity is behind the local branch containing the
feature.

## Prevention / Rule
**Guardrail:** Record the deployed frontend commit or content hash and require
the staging smoke check to assert a feature-specific marker before declaring a
feature available.

This prevents a stale static bundle from being mistaken for a successful
deployment merely because the route returns HTTP 200.

## Solution

### Immediate Fix
No staging mutation was performed. The feature is not available at the
requested URL.

### Long-term Fix
Deploy the commit containing `14ccc2c` through the normal staging process, then
verify the rendered edit action and a real save journey with an authorized
institution user.

## Prevention
- [ ] Publish immutable frontend artifact identity for staging
- [ ] Add a feature-specific staging smoke assertion
- [ ] Verify authorized edit/save behavior after deployment

## Related Issues
- `TESC-2026-11-07-green-artifact-identity-drift.md`

## References
- `inst/src/pages/Inclusivity.tsx`
- `inst/src/components/EditInclusivityCategoryDialog.tsx`
- Commit `14ccc2c1da6655c177236c175cfc36d3e3cd262f`
- `https://tesc-inst-staging.zchpc.ac.zw/dashboard/inclusivity`

---

**Resolved By:** Copilot
**Time to Resolution:** Not resolved; staging deployment required
