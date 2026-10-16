# Duplicate Manager Attendance Actions

**Date:** 2026-10-16
**Project:** ZCHPC-ERP
**Environment:** Development / Review
**Severity:** Low
**Status:** Investigating

## Summary
The `master` branch renders two manager quick actions with the same label and destination, producing duplicate React list keys and duplicated attendance navigation in the manager dashboard.

## Symptoms
- The employee portal Vitest suite passes but emits `Encountered two children with the same key, My Attendance`.
- The manager dashboard contains two `My Attendance` cards, both linking to `/portal/attendance`.

## Environment Details
- **Server/Host:** Local review worktree
- **Services Affected:** Employee portal
- **Related Components:** `ManagerDashboard`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
The warning appeared while running the complete employee portal Vitest suite against `origin/master`.

### 2. Root Cause Analysis
`quickActions.map()` uses `action.label` as the React key. `ManagerDashboard` defines two separate actions with the label `My Attendance`, and both point to the same route.

```bash
rg -n "My Attendance" employee-portal/src/components/dashboard/role/ManagerDashboard.tsx
```

### 3. Key Findings
- The duplicate key is deterministic, not test-only.
- The duplicate cards are functionally redundant.
- The current build succeeds, but React warns that child identity is unsupported.

## Root Cause
The manager dashboard quick-action list added a second attendance entry without removing or renaming the existing action, while the renderer assumes labels are unique keys.

## Prevention / Rule
**Guardrail:** Add a frontend test that asserts each dashboard quick-action key/route pair is unique, and use a stable action identifier rather than display text as the React key.

This catches duplicate navigation entries before merge and prevents a label change from changing component identity.

## Solution

### Immediate Fix
Not applied during the review; the branch was kept unchanged.

### Long-term Fix
Remove the redundant attendance action or give it a distinct purpose, then key the rendered action by a stable identifier.

## Prevention
- [ ] Add a unique-action assertion to dashboard component tests
- [ ] Replace display-label React keys with stable IDs
- [ ] Review manager dashboard navigation for duplicate destinations

## Related Issues
- The overall merge review is recorded in `reports/ZCHPC-ERP-2026-10-16-master-before-main-code-review.md`.

## References
- `employee-portal/src/components/dashboard/role/ManagerDashboard.tsx:76-98`
- Employee portal test output from the master review

---

**Resolved By:** Pending
**Time to Resolution:** Pending
