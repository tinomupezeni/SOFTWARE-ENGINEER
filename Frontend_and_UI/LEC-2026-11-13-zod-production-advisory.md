# Zod Production Dependency Advisory

**Date:** 2026-11-13
**Project:** LEC Biotec
**Environment:** Development pre-deployment verification
**Severity:** Medium
**Status:** Investigating

## Summary
The admin bundle uses Zod 3.25.76 and npm audit flags versions below 4.6.6 for an oversized-array validation memory-exhaustion advisory. The application's only Zod schema is the staff sign-in form with `email` and `password` strings; it has no array schema, and validation runs in the browser. This pass found no reachable path matching the advisory, but the production dependency alert remains.

## Symptoms
- `npm audit --omit=dev` reports one high-severity advisory for `zod`.
- The lockfile resolves `zod` to 3.25.76.

## Environment Details
- **Server/Host:** Local checkout and npm registry advisory feed
- **Services Affected:** Admin browser bundle
- **Related Components:** `apps/admin/src/features/auth/SignInPage.tsx`, `apps/admin/package.json`, root lockfile
- **Time First Observed:** 2026-11-13

## Investigation Steps

### 1. Initial Diagnosis
Separated production from development-only npm audit findings after the web image build.

### 2. Root Cause Analysis
Read the advisory's affected operation and searched all app Zod imports and schemas.

```bash
npm audit --omit=dev --json
rg -n 'from "zod"|z\\.array|safeParse' apps packages
```

### 3. Key Findings
- The advisory describes unbounded issues from oversized array validation.
- The admin sign-in form is the only Zod call site and validates two strings.
- No server process executes this JavaScript schema; the production web image serves static files.

## Root Cause
The app remains on Zod 3.x while npm's advisory range flags every version below 4.6.6. Upgrading Zod would also require checking the form resolver's compatibility.

## Prevention / Rule
**Guardrail:** Keep a release-gate record of production advisory call sites and require an updated assessment whenever Zod schemas or the installed version change.

This will catch a future array schema that could make the currently unreachable advisory path relevant.

## Solution

### Immediate Fix
No code change was made: the affected array-validation operation is absent from this application. The alert remains open for dependency migration planning.

### Long-term Fix
Upgrade Zod and its form resolver together after compatibility tests, or document a reviewed exception while the schema remains string-only and browser-side.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Dependency update required to clear the alert

## Related Issues
- `LEC-2026-11-13-react-router-production-advisories.md`

## References
- https://github.com/advisories/GHSA-mrhx-c7xc-m3w5
- `apps/admin/src/features/auth/SignInPage.tsx`

---

**Resolved By:** Pending
**Time to Resolution:** Open
