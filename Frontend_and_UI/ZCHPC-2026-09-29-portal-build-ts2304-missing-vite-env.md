# Portal frontend Docker build broken: `__API_URL__` unknown to tsc (TS2304)

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Environment:** Development (local + staging image build on erp-vm)
**Severity:** High
**Status:** Resolved

## Summary

`npm run build` in `employee-portal/` failed inside the Docker builder with
`src/services/api.ts(9,67): error TS2304: Cannot find name '__API_URL__'`,
so the portal image could not be built and the staging rebuild on erp-vm
aborted. A 3-line ambient declaration file fixed it; verified with `tsc -b`
and full `vite build`, merged via PR #32.

## Symptoms

- `docker compose up -d --build ... portal` on erp-vm staging failed:
  `target portal: failed to solve: process "/bin/sh -c npm run build" did
  not complete successfully: exit code: 2`
- Local `main` had the same failure — any fresh portal build was broken.

## Environment Details

- **Server/Host:** erp-vm (10.50.14.12), `~/zchpc-erp-staging`, plus local checkout
- **Services Affected:** employee-portal frontend build only (admin frontend,
  which uses `import.meta.env`, built fine)
- **Related Components:** `employee-portal/src/services/api.ts`,
  `employee-portal/vite.config.ts`, `employee-portal/Dockerfile`
- **Time First Observed:** 2026-09-29 during staging rebuild

## Investigation Steps

### 1. Initial Diagnosis

Read the failing file and the vite config. `api.ts:9` references a
compile-time global `__API_URL__`; `vite.config.ts` provides it via the
`define` block, which only exists at vite-bundle time.

### 2. Root Cause Analysis

`npm run build` is `tsc -b && vite build` — tsc runs first and knows
nothing about vite `define` globals unless they are declared. A glob for
`employee-portal/src/*.d.ts` found **no declaration file at all**, while
`s zchpc-erp-synergy-main/src/vite-env.d.ts` exists. `git log` showed
`__API_URL__` was introduced by F27-PR (`0af6732`) without the declaration.

```bash
git log --oneline -5 -- employee-portal/src/services/api.ts employee-portal/vite.config.ts
ls employee-portal/src/*.d.ts  # no files
```

### 3. Key Findings

- The bug was pre-existing on `main`, not caused by the rebuild: the
  deployed `:latest` portal image (~Sep 18) simply predates F27-PR.
- Admin frontend was unaffected (different env mechanism).
- The failed compose run left staging containers on old images — no partial
  rollout occurred.

## Root Cause

Vite `define` globals are invisible to `tsc`. The portal had no
`src/vite-env.d.ts`, so the F27-PR change compiled in the author's editor
(likely with looser checks or a stale cache) but broke every clean
`tsc -b` build, including Docker.

## Prevention / Rule

**Guardrail:** CI gate that runs `npm run build` (which includes `tsc -b`)
for each frontend on every PR touching it — a build that never runs in CI
is a build that breaks silently.

Without a per-frontend build check, type-level breakage like an undeclared
`define` global lands on `main` undetected until deploy time.

## Solution

### Immediate Fix

Added `employee-portal/src/vite-env.d.ts`, mirroring the admin frontend
convention plus the new global:

```ts
/// <reference types="vite/client" />

declare const __API_URL__: string;
```

### Long-term Fix

- PR #32 (`fix/portal-vite-env-api-url` → `main`, merge commit `f5b4c00`);
  direct push was correctly rejected by branch protection, PR merged clean.
- Add the CI build gate above so the next missing declaration fails the PR,
  not the deploy.

## Prevention

- [x] Code changes required (done, PR #32)
- [ ] CI: per-frontend `npm run build` on PRs (to add)
- [ ] Documentation to update (none needed — matches existing convention)

## Related Issues

- Staging rebuild report: `reports/ZCHPC-2026-09-29-staging-rebuild-from-main.md`
- Companion incident during same rebuild:
  `DevOps_and_Infrastructure/ZCHPC-2026-09-29-staging-compose-absolute-names-collision.md`

## References

- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/32
- `employee-portal/vite.config.ts` (`define.__API_URL__`)

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** ~30 min (diagnose, fix, verify locally, PR, merge)
