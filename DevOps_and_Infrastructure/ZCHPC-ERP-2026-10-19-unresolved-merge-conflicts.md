# Unresolved Merge Conflicts in ZCHPC-ERP Worktree

**Date:** 2026-10-19
**Project:** ZCHPC ERP
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
The ZCHPC-ERP worktree is not in a clean, build-safe state: seven tracked paths
are reported by Git as unmerged. The conflicts span Django app configuration
and the ERP admin inventory/CRM service surface, so the repository cannot be
treated as a reliable baseline until the merge is resolved.

## Symptoms
- `git status --short --branch` reports `DU` or `UU` entries.
- `git diff --name-only --diff-filter=U` lists six unresolved paths.
- The affected files include application registrations and frontend services,
  making both backend startup and frontend compilation potentially ambiguous.

## Environment Details
- **Server/Host:** Local Linux development worktree
- **Services Affected:** Django backend and ERP admin frontend
- **Related Components:** `erp_project/src/modules/{assets,crm,inventory,projects}`,
  `zchpc-erp-synergy-main/src/pages/InventoryPage.tsx`, and related services
- **Time First Observed:** 2026-10-19 during repository orientation

## Investigation Steps

### 1. Initial Diagnosis
Read the repository documentation and inspected the current Git status before
examining application boundaries and entrypoints.

### 2. Root Cause Analysis
```bash
git status --short --branch
git diff --stat
git diff --name-only --diff-filter=U
```

### 3. Key Findings
- `erp_project/src/modules/assets/apps.py` is unmerged.
- `erp_project/src/modules/crm/apps.py` is unmerged.
- `erp_project/src/modules/inventory/apps.py` is unmerged.
- `erp_project/src/modules/projects/apps.py` is unmerged.
- `zchpc-erp-synergy-main/src/pages/InventoryPage.tsx` is unmerged.
- `zchpc-erp-synergy-main/src/services/crm.services.ts` is unmerged.
- `zchpc-erp-synergy-main/src/services/inventory.services.ts` is unmerged.

## Root Cause
An incomplete Git merge or rebase left conflict entries in the index. The
conflict state is independent of the application architecture and was not
resolved during this read-only orientation pass.

## Prevention / Rule
**Guardrail:** Add a CI preflight that fails when
`git diff --name-only --diff-filter=U` returns any path.

This prevents a branch containing unresolved index entries from reaching build,
test, or deployment gates where the selected side of a conflict is not
explicitly reviewed.

## Solution

### Immediate Fix
No source conflicts were resolved. The repository was left unchanged so the
pending merge remains visible to the owner of the in-progress work.

### Long-term Fix
Resolve each conflict deliberately, then run backend checks and both frontend
build/lint checks before merging or deploying.

## Prevention
- [ ] Add an unresolved-conflict CI preflight
- [ ] Resolve and review all six affected conflict groups
- [ ] Run backend and frontend validation after resolution

## Related Issues
- None identified during this pass.

## References
- `/home/shadowe/Projects/ZCHPC-ERP` Git status captured on 2026-10-19
- `GEMINI.md` project SOPs

---

**Resolved By:** Unassigned
**Time to Resolution:** Open
