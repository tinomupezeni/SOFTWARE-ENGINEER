# Frontend release build used an incomplete local dependency install

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Development / Release build
**Severity:** Medium
**Status:** Investigating

## Summary
The promoted frontend source declares `react-markdown` and `remark-gfm`, but the local `node_modules` directory did not contain `react-markdown`. The release build therefore failed during Vite bundling before any image was built or deployed.

## Symptoms
- `npm run build` failed to resolve `react-markdown` from `src/pages/help/HelpComponents.tsx`.
- `package.json` and `package-lock.json` both declare the dependency.
- `npm ls react-markdown --depth=0` reported an empty installation.

## Environment Details
- **Server/Host:** Local release workstation
- **Services Affected:** ProjectFlow frontend release build
- **Related Components:** `projectflow-hq/package.json`, `package-lock.json`, `node_modules`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Ran the production frontend build on the promoted `main` branch.

### 2. Root Cause Analysis
Compared the unresolved import with the dependency manifests and queried the installed dependency tree.

```bash
npm run build
npm ls react-markdown --depth=0
```

### 3. Key Findings
- The dependency is present in both manifests.
- The dependency is absent from the local installation.
- The failure is a release-workstation dependency drift issue, not an application import or production runtime error.

## Root Cause
The local frontend dependencies were not installed or synchronized after promoting the staging source line.

## Prevention / Rule
**Guardrail:** Run `npm ci` from the checked-out frontend release commit before every production build and fail the release if the lockfile installation or build fails.

`npm ci` creates a clean dependency tree from the committed lockfile, preventing a stale or partial `node_modules` directory from masking release-build failures.

## Solution

### Immediate Fix
Pending: install the committed dependency set with `npm ci`, then rerun the production build.

### Long-term Fix
Make clean lockfile installation and a production bundle smoke test mandatory pre-deployment gates.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-frontend-source-drift-regression.md`
- `ProjectFlow-2026-10-15-frontend-api-loopback-regression.md`

## References
- `projectflow-hq/package.json`
- `projectflow-hq/package-lock.json`
- `projectflow-hq/src/pages/help/HelpComponents.tsx`

---

**Resolved By:** Unassigned
**Time to Resolution:** Ongoing
