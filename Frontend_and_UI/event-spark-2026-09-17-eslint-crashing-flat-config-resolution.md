# ESLint Flat Config Resolution Crash & Prettier Conflict

**Date:** 2026-09-17
**Project:** event-spark
**Environment:** Development / CI
**Severity:** Medium
**Status:** Resolved

## Summary
`npm run lint` was crashing in CI and locally because `eslint.config.js` was placed at the repository root where no `package.json` existed (except an orphaned `node_modules` locally). ESLint flat config resolves imports relative to the config file, so it failed with `ERR_MODULE_NOT_FOUND` in CI where only the `frontend/` directory installed dependencies. Additionally, a formatting conflict occurred between `eslint-plugin-prettier` and `format:check` due to different Prettier versions.

## Symptoms
- `npm run lint` crashed with `ERR_MODULE_NOT_FOUND`.
- CI lint checks failed to run properly.
- `eslint-plugin-prettier` formatting rules contradicted `format:check` formatting rules, making it impossible to satisfy both lint and format gates simultaneously.

## Environment Details
- **Server/Host:** Local & CI
- **Services Affected:** Frontend Linting and Formatting
- **Related Components:** `eslint.config.js`, `frontend/package.json`
- **Time First Observed:** During local CI gate verification

## Investigation Steps

### 1. Initial Diagnosis
The `npm run lint` command resulted in module resolution errors for ESLint plugins.

### 2. Root Cause Analysis
By investigating the directory structure, it was observed that `eslint.config.js` resided at the root of the repository, but the dependencies required by it were installed inside `frontend/node_modules`. ESLint flat config (`eslint.config.js`) evaluates plugin imports relative to the configuration file's location.

Additionally, the local orphaned `node_modules` at the root contained Prettier `3.8.4` (used by ESLint), while the frontend's explicit installation used Prettier `3.9.6` (used by `format:check`). This caused disagreements in formatting (e.g., short union types).

### 3. Key Findings
- Flat configs must live alongside the `package.json` that defines their plugin dependencies.
- Conflicting Prettier versions across different contexts will result in unresolvable formatting wars.

## Root Cause
The flat configuration file for ESLint was incorrectly located at the repository root instead of the `frontend/` subproject root, leading to incorrect module resolution and usage of an orphaned, outdated local `node_modules`.

## Prevention / Rule
**Guardrail:** Tooling configuration files (`eslint.config.js`, `tsconfig.json`, `vite.config.ts`) must always reside in the same directory as the `package.json` that defines their dependencies in a multi-project repository.

This ensures all module resolutions map strictly to the dependencies installed for that specific workspace/project, avoiding orphaned or global dependency leakage.

## Solution

### Immediate Fix
Moved `eslint.config.js` from the repository root into the `frontend/` directory where the plugins are actually declared and installed. 

This simultaneously resolved the `ERR_MODULE_NOT_FOUND` issue and the Prettier version mismatch, as both tools now properly utilize the dependencies defined in `frontend/package.json`. Formatted the resulting surfaced lint errors (whitespace only) in `login.tsx`, `signup.tsx`, and `validation.ts`.

### Long-term Fix
Maintain strict isolation of frontend and backend tooling environments.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- N/A

## References
- PR #2 in `winstonjthinker/event-spark`

---

**Resolved By:** Antigravity
**Time to Resolution:** Fixed in PR #2
