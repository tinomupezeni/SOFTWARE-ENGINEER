# React Router Production Dependency Advisories

**Date:** 2026-11-13
**Project:** LEC Biotec
**Environment:** Development pre-deployment verification
**Severity:** Medium
**Status:** Workaround Applied

## Summary
The committed web lockfile used React Router 6.30.4, which npm audit flagged in production dependencies. A compatible update to 6.30.6 removed the direct `react-router-dom` open-redirect-to-XSS advisory, but npm audit still reports the React Router 6.x core for a backslash navigation advisory and an SSR hydration advisory. No attacker-controlled navigation target or SSR hydration path was demonstrated in this application.

## Symptoms
- `npm audit --omit=dev` reported `react-router` and `react-router-dom` advisories.
- The original lockfile resolved both packages to 6.30.4.
- After upgrading to 6.30.6, the direct `react-router-dom` XSS advisory disappeared; the core advisory remains.

## Environment Details
- **Server/Host:** Local checkout and npm registry advisory feed
- **Services Affected:** Storefront and admin browser bundles
- **Related Components:** Both app package manifests, root lockfile, navigation components
- **Time First Observed:** 2026-11-13

## Investigation Steps

### 1. Initial Diagnosis
Triaged the `npm ci` security warning from the production web image build with `npm audit --omit=dev`.

### 2. Root Cause Analysis
Compared locked versions with the advisory ranges and inspected app navigation: dynamic catalogue targets are encoded or validated slugs; editable menu targets require staff access; this Vite SPA does not use React Router SSR hydration.

```bash
npm audit --omit=dev --json
rg -n 'useNavigate|navigate\\(|<Link' apps/storefront/src apps/admin/src
```

### 3. Key Findings
- React Router 6.30.6 is the compatible patch for the direct DOM package advisory.
- The remaining core advisory reports an affected range through React Router 7.17.0, so a 6.x patch cannot clear it.
- No lower-trust path to the affected navigation API was demonstrated during this pass; this is a dependency alert, not a confirmed application exploit.

## Root Cause
The lockfile retained an older affected React Router patch version, and the app remains on the 6.x major that the later core advisory covers.

## Prevention / Rule
**Guardrail:** Run `npm audit --omit=dev` in the release gate and record a code-path assessment for any production advisory that cannot be patched within the current major.

This prevents a green build from hiding a new production dependency alert while distinguishing a version alert from a reachable application vulnerability.

## Solution

### Immediate Fix
Updated both apps to `react-router-dom@6.30.6` and regenerated the lockfile entries for `react-router` and `@remix-run/router`.

### Long-term Fix
Plan and verify a React Router 7 migration, or document a reviewed exception tied to the absence of untrusted navigation targets and SSR hydration.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Compatible code dependency update applied

## Related Issues
- `LEC-2026-11-13-zod-production-advisory.md`

## References
- https://github.com/advisories/GHSA-jjmj-jmhj-qwj2
- https://github.com/advisories/GHSA-wrjc-x8rr-h8h6
- https://github.com/advisories/GHSA-337j-9hxr-rhxg

---

**Resolved By:** Codex (partial remediation)
**Time to Resolution:** Open
