# Web Build Reports Circular Chunk Imports

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development build
**Severity:** Medium
**Status:** Investigating

## Summary
The student web production build succeeds but Rollup warns that barrel reexports and dynamic/static mixed imports may create circular chunk dependencies or prevent intended code splitting. This was observed while validating the mobile WebView practice route.

## Symptoms
- Vite warns that `useTheme`, `useMotionBudget`, and `EducationScene` reexports can produce circular dependency between chunks and broken execution order.
- Vite reports dynamic imports of modules also imported statically, including `src/lib/api.ts` and several auth/offline modules.

## Environment Details
- **Server/Host:** Local HBEC checkout
- **Services Affected:** Student web production bundle
- **Related Components:** Theme, grammar, illustration barrels; Vite chunk configuration
- **Time First Observed:** 2026-11-05

## Investigation Steps

### 1. Initial Diagnosis
Ran the production bundle while validating the mobile practice handoff.

### 2. Root Cause Analysis
Read Vite's emitted warnings naming the mixed import paths and reexports.

```bash
npm run build -- --outDir /tmp/hbec-web-practice-build
```

### 3. Key Findings
- Build exits successfully, so this is a potential runtime/code-splitting defect, not a proven failure on a user device.
- The warning names `SubjectCanvas`, `AppearanceCard`, and other consumers of barrel exports.
- Dynamic imports of statically imported modules cannot move those modules into separate chunks.

## Root Cause
The import graph mixes barrel reexports, circular dependencies, and static/dynamic imports for the same modules.

## Prevention / Rule
**Guardrail:** Treat Rollup circular chunk warnings as a CI build gate after replacing the named barrel imports with direct module imports or grouping those exports in one chunk.

The gate would catch a recurrence before shipping a bundle whose execution order is uncertain.

## Solution

### Immediate Fix
No import graph change was made in this focused mobile practice fix. The production bundle completed successfully and is available under `/tmp/hbec-web-practice-build` for inspection.

### Long-term Fix
Resolve each named circular chunk path and mixed import path, then enable the warning gate.

## Prevention
- [ ] Code changes required
- [ ] Monitoring/alerts to add
- [ ] Configuration changes needed
- [ ] Documentation to update

## Related Issues
- None

## References
- Vite/Rollup production build output on 2026-11-05

---

**Resolved By:** Pending
**Time to Resolution:** Pending
