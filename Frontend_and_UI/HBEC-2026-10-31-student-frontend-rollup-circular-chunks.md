# Student frontend build reports circular chunk dependencies

**Date:** 2026-10-31
**Project:** HBEC
**Environment:** Local build and production release source
**Severity:** Medium
**Status:** Investigating

## Summary
The student frontend production build succeeds but Rollup warns that barrel re-exports and direct imports place cyclic modules in different output chunks. Rollup says this may produce a broken execution order. The warnings predate the phone number profile card change.

## Symptoms
- `npm run build` warns about `useTheme`, `useMotionBudget`, and `EducationScene` re-exports through barrel modules.
- The build completes despite the warnings.
- No user-facing failure from these cycles has been confirmed in this session.

## Environment Details
- **Server/Host:** Local HBEC checkout; production artifact uses the same frontend source.
- **Services Affected:** Student frontend build and runtime chunk loading.
- **Related Components:** `src/shared/theme`, `src/shared/grammar`, `src/shared/illustrations`, Vite manual chunk configuration.
- **Time First Observed:** 2026-10-31 profile card build.

## Investigation Steps

### 1. Initial Diagnosis
Ran the student frontend production build while validating the profile phone card.

### 2. Root Cause Analysis
Rollup identifies modules imported both directly and through barrel re-exports, with the exporter and re-exporter ending up in separate chunks. The dependency graph and runtime impact need focused investigation.

```bash
cd STUDENT/Frontend
npm run build
```

### 3. Key Findings
- The build transformed 6,112 modules and completed.
- The warnings name `SubjectCanvas.tsx`, `AppearanceCard.tsx`, and several shared components.
- The new phone card does not import the warned theme, grammar, or illustration barrels.

## Root Cause
Circular re-export paths cross Rollup's output chunk boundaries. The exact import edges to change have not yet been fully traced.

## Prevention / Rule
**Guardrail:** Fail the frontend build on Rollup circular chunk warnings, after resolving the current cycles by importing directly from exporting modules or keeping each cycle in one chunk.

This makes future build artifacts reject the execution-order risk instead of silently shipping it.

## Solution

### Immediate Fix
The phone card build succeeded. The pre-existing circular chunk warnings remain open.

### Long-term Fix
Trace and remove the barrel re-export cycles, then enable the build guardrail.

## Prevention
- [ ] Remove the reported circular import paths.
- [ ] Add a CI build gate for circular chunk warnings.

## Related Issues
- None recorded.

## References
- `STUDENT/Frontend/vite.config.ts`
- `STUDENT/Frontend/src/shared/theme/index.ts`

---

**Resolved By:** Pending
**Time to Resolution:** Ongoing
