# Dead-code scan tooling produces false positives

**Date:** 2026-10-14
**Project:** TESE-MARKET (BFF)
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
The customer-store `find-unused-files.js` script reports most of the application as unused even though the files are reachable through `@/` aliases and barrel exports. Its output is therefore unsafe as a deletion list.

## Symptoms
- Running `node apps/customer-store/find-unused-files.js` reported 202 potentially unused files.
- The report included active routes, providers, shared UI components, and feature pages imported by `src/App.tsx`.
- The repository's own cleanup documentation already warns that the script produces false positives.

## Environment Details
- **Server/Host:** Local development workspace
- **Services Affected:** Customer-store maintenance tooling
- **Related Components:** `apps/customer-store/find-unused-files.js`, customer-store TypeScript/Vite source graph
- **Time First Observed:** 2026-10-14

## Investigation Steps

### 1. Initial Diagnosis
Ran the repository-provided unused-file script, then compared its output with the customer-store route graph and barrel exports.

### 2. Root Cause Analysis
The script resolves `@/` imports by stripping the alias but does not preserve the source-root context during recursive resolution. It also uses a fragile regular expression for import extraction and does not model the application's barrel exports reliably.

```bash
node apps/customer-store/find-unused-files.js
```

### 3. Key Findings
- `src/App.tsx` imports active providers, routes, and feature entry points that appeared in the unused report.
- `src/features/home/index.ts` and `src/shared/components/index.ts` are active barrel boundaries but are not handled safely by the script.
- `apps/customer-store/docs/CLEANUP_SUMMARY.md` documents the false-positive behavior, but the script remains available as a deletion-adjacent tool.

## Root Cause
The custom scanner is a text/relative-path heuristic rather than a resolver-aware dependency graph, so aliases, index files, and barrel exports are interpreted incorrectly.

## Prevention / Rule
**Guardrail:** Replace the custom scanner with a resolver-aware dead-code tool or a tested graph implementation that uses the workspace TypeScript/Vite aliases and requires a passing build before producing deletion candidates.

This prevents path-alias and barrel-resolution failures from turning a maintenance report into destructive cleanup instructions.

## Solution

### Immediate Fix
No source files were deleted. The generated `unused-files.json` report was removed after review.

### Long-term Fix
Retire or rewrite `find-unused-files.js`, add a fixture-based test for `@/` imports and index barrels, and mark any output as advisory until the graph is validated against the build.

## Prevention
- [ ] Replace the heuristic scanner with resolver-aware analysis
- [ ] Add alias/barrel fixtures to the scanner test
- [ ] Keep deletion candidates separate from automatically deletable files
- [ ] Update cleanup documentation after the tool is corrected

## Related Issues
- `TESE-MARKET-2026-10-14-typecheck-baseline-failing.md`

## References
- `apps/customer-store/find-unused-files.js:37-55, 87-148`
- `apps/customer-store/src/App.tsx`
- `apps/customer-store/src/features/home/index.ts`
- `apps/customer-store/src/shared/components/index.ts`
- `apps/customer-store/docs/CLEANUP_SUMMARY.md`

---

**Resolved By:** Copilot
**Time to Resolution:** Investigation completed; remediation deferred
