# HCI Rollout Deployment Failures

**Date:** 2026-05-09
**Project:** CRM
**Environment:** Development / Build Pipeline
**Severity:** Critical
**Status:** Resolved

## Summary
Multiple deployment failures were encountered during the implementation of HCI parity between the web and mobile platforms. These ranged from simple missing dependencies to deep architectural incompatibilities between Vite and React Native.

## Symptoms
- Docker build failures during the pnpm install and ite build stages.
- ERR_PNPM_OUTDATED_LOCKFILE during containerization.
- [commonjs--resolver] Expected 'from', got 'typeOf' error during Vite transformation.

## Environment Details
- **Server/Host:** Win32 (Local) / Docker (Build)
- **Services Affected:** @crm/web, @crm/ui
- **Related Components:** SaleForm, useTheme hook, GlobalSearch
- **Time First Observed:** 10:43 AM

## Investigation Steps

### 1. Initial Diagnosis
Checked package.json dependencies and verified presence of newly added libraries.

### 2. Root Cause Analysis
- Identified that 'zustand' was added to code but not to manifest.
- Identified that updating package.json manually invalidated the lockfile for the 'frozen-lockfile' build step.
- Identified that importing React Native components into a Vite/Rollup environment introduced incompatible Flow-specific syntax (import typeof).

`ash
# Commands used for investigation
pnpm typecheck
docker compose -f docker-compose.yml build
`

### 3. Key Findings
- Dependency manifests must be updated on the host and synchronized with the lockfile before Docker builds.
- Shared monorepo packages containing React Native code are NOT safe for direct import into Vite-based web apps without specialized transpilaton.

## Root Cause
1. Incomplete dependency declaration for the 'zustand' library.
2. Inconsistent lockfile state due to manual package.json edits.
3. Cross-platform architectural conflict: Web app importing React Native primitives.

## Solution

### Immediate Fix
- Explicitly added 'zustand' to apps/web/package.json.
- Synchronized pnpm-lock.yaml by running 'pnpm install' on the host.
- Refactored web-native versions of 'QuickProductGrid' and 'PriceStepper' to eliminate the '@crm/ui' (React Native) dependency.

`ash
# Commands used to fix
pnpm install
pnpm typecheck
`

### Long-term Fix
- Ensure all new dependencies are added via the CLI (pnpm add) or immediately followed by a host-side pnpm install.
- Maintain strict separation between React Native UI components and Web UI components, utilizing only raw logic or types in shared packages.

## Prevention
- [x] Configuration changes needed (strict dependency checks)
- [ ] Monitoring/alerts to add
- [x] Documentation to update (cross-platform sharing rules)
- [x] Code changes required (web-native refactors)

## References
- Vite issue #... (React Native incompatibility)
- pnpm documentation on frozen-lockfile

---

**Resolved By:** Gemini CLI
**Time to Resolution:** ~1 hour
