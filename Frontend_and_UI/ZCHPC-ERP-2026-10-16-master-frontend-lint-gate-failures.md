# Master Frontend Lint Gate Failures

**Date:** 2026-10-16
**Project:** ZCHPC-ERP
**Environment:** Development / Review
**Severity:** Medium
**Status:** Investigating

## Summary
The `master` branch does not pass the configured ESLint gates for either frontend application. The employee portal reports 9 errors and the ERP admin frontend reports 48 errors, including hook-order/closure analysis errors, unsafe `any` usage, and invalid import/style rules.

## Symptoms
- Employee portal build succeeds, but ESLint exits non-zero with 9 errors and 7 warnings.
- ERP admin frontend lint exits non-zero with 48 errors and 19 warnings.
- Examples include `QRScanner.tsx` accessing `handleScan` before declaration, synchronous state updates inside `QRDisplayPage` effects, and extensive `no-explicit-any` violations.

## Environment Details
- **Server/Host:** Local clean detached review worktree
- **Services Affected:** `employee-portal`, `zchpc-erp-synergy-main`
- **Related Components:** Frontend source and ESLint configuration
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran the configured ESLint binaries against both frontend trees after linking the complete existing dependency trees into the clean `master` review worktree.

### 2. Root Cause Analysis
The incoming branch contains implementation changes that are incompatible with the repository's active lint rules, and the branch has no passing lint gate before merge.

```bash
employee-portal/node_modules/.bin/eslint .
zchpc-erp-synergy-main/node_modules/.bin/eslint .
```

### 3. Key Findings
- `employee-portal/src/components/attendance/QRScanner.tsx:51-74` violates the hook/closure rule by using `handleScan` before declaration and omitting it from the effect dependency list.
- `employee-portal/src/pages/QRDisplayPage.tsx:27` triggers the configured `react-hooks/set-state-in-effect` error.
- Both frontends contain many `no-explicit-any` errors, so the failure is broader than one file.
- Both application builds still complete successfully; build success does not satisfy the configured lint gate.

## Root Cause
The master change set was merged without resolving the active lint policy violations introduced or exposed by the changed frontend code.

## Prevention / Rule
**Guardrail:** Make both frontend lint commands required CI checks and fail the merge when either exits non-zero.

The issue is a release-quality gate failure; a required CI check prevents a large lint debt from reaching `main` even when TypeScript compilation and bundling succeed.

## Solution

### Immediate Fix
Not applied during the review; the branch was kept unchanged.

### Long-term Fix
Resolve the hook-order/dependency errors first, replace unsafe `any` types in changed code, and either fix or explicitly document any legacy rule exceptions before re-running the complete lint gates.

## Prevention
- [ ] Require employee portal ESLint in CI
- [ ] Require ERP admin ESLint in CI
- [ ] Fix changed-file lint errors before merge
- [ ] Avoid broad rule suppression

## Related Issues
- The overall merge review is recorded in `reports/ZCHPC-ERP-2026-10-16-master-before-main-code-review.md`.

## References
- `employee-portal/src/components/attendance/QRScanner.tsx:51-74`
- `employee-portal/src/pages/QRDisplayPage.tsx:25-31`
- Master review ESLint outputs

---

**Resolved By:** Pending
**Time to Resolution:** Pending
