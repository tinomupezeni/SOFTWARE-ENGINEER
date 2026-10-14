# Type-check baseline is failing in both frontend applications

**Date:** 2026-10-14
**Project:** TESE-MARKET (BFF)
**Environment:** Development
**Severity:** High
**Status:** Investigating

## Summary
Both frontend TypeScript checks fail, so type-checking cannot currently serve as a reliable safety gate for dead-code deletion. The customer-store has many existing type and module-resolution errors, while the admin-dashboard has a syntax error in a tracked type definition.

## Symptoms
- Customer-store `tsc --noEmit` reports errors across routing props, cart/payment APIs, profile and product-detail imports, and type mismatches.
- Admin-dashboard `tsc --noEmit` fails immediately on `src/lib/types/projections.ts`.
- Both Vite production builds still complete, allowing broken type contracts to remain hidden from the build command.

## Environment Details
- **Server/Host:** Local development workspace
- **Services Affected:** Customer-store and admin-dashboard frontend quality gates
- **Related Components:** TypeScript project configs and frontend source
- **Time First Observed:** 2026-10-14

## Investigation Steps

### 1. Initial Diagnosis
Ran the application-level TypeScript checks and production builds through the workspace package manager.

### 2. Root Cause Analysis
The build pipeline transpiles and bundles successfully without requiring a clean TypeScript program. The admin syntax error is a concrete source defect; the customer-store errors indicate drift between feature contracts, service types, and imports.

```bash
corepack pnpm --filter @tese/customer-store exec tsc -p tsconfig.app.json --noEmit
corepack pnpm --filter @tese/admin-dashboard exec tsc -p tsconfig.app.json --noEmit
corepack pnpm --filter @tese/customer-store exec vite build
corepack pnpm --filter @tese/admin-dashboard exec vite build
```

### 3. Key Findings
- `apps/admin-dashboard/src/lib/types/projections.ts:7` contains `capabilities: any{}` instead of a valid TypeScript property type.
- Customer-store reports unresolved imports such as `../../types/customerProfile.types` from component files.
- Production builds pass despite the type-check failures.

## Root Cause
Type-checking is not enforced as a release gate, and the codebase has accumulated incompatible or stale type contracts while the bundler remains permissive.

## Prevention / Rule
**Guardrail:** Add a CI-required `tsc --noEmit` task for each frontend workspace and make deployment depend on that task succeeding.

This closes the gap between “bundles successfully” and “source contracts are valid,” preventing dead-code cleanup from being performed against an already-invalid baseline.

## Solution

### Immediate Fix
No unrelated type fixes were made during the dead-code scan. The failing baseline is recorded as a prerequisite for safe cleanup.

### Long-term Fix
Correct the admin syntax error, repair customer-store module paths and feature contracts, then add the checks to the workspace CI/deployment gate.

## Prevention
- [ ] Fix `capabilities: any{}` in the projections type
- [ ] Repair customer-store unresolved imports and contract mismatches
- [ ] Add workspace type-check scripts
- [ ] Make CI/deployment fail on type-check errors

## Related Issues
- `TESE-MARKET-2026-10-14-dead-code-scan-tooling-false-positives.md`

## References
- `apps/admin-dashboard/src/lib/types/projections.ts:1-8`
- `apps/admin-dashboard/src/App.tsx:1-55`
- `apps/customer-store/src/features/customer-profile/components/AccountOverview.tsx`
- `apps/customer-store/src/features/product-detail/components/BuyBox.tsx`
- `apps/customer-store/package.json`
- `apps/admin-dashboard/package.json`

---

**Resolved By:** Copilot
**Time to Resolution:** Investigation completed; remediation deferred
