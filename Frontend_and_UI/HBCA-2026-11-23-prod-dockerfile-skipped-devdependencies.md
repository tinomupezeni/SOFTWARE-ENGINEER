# Frontend production Dockerfile skipped devDependencies, build failed

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps, first real deploy)
**Severity:** High
**Status:** Resolved

## Summary
`frontend/Dockerfile`'s `build` stage set `NODE_ENV=production` before `npm install`, so npm skipped `devDependencies` — exactly where `typescript` and `vite` live, both required by `npm run build` (`tsc -b && vite build`). `sh: tsc: not found`, exit 127. This had existed since the Dockerfile was written but was never caught, because this was the first time a production frontend image was actually built.

## Symptoms
- `docker build --target prod` failed at the `RUN npm run build` step with `sh: tsc: not found`, exit code 127.

## Environment Details
- **Server/Host:** hbca-vps (GitHub Actions self-hosted runner)
- **Services Affected:** hbca-classroom-frontend image build
- **Related Components:** `frontend/Dockerfile`
- **Time First Observed:** 2026-11-23, first production deploy workflow run

## Investigation Steps

### 1. Initial Diagnosis
Build log showed `npm run build` failing immediately with `tsc: not found`, despite `typescript` being listed in `package.json`.

### 2. Root Cause Analysis
`npm install` honors `NODE_ENV` at install time by skipping `devDependencies` when it's set to `production` — and the Dockerfile set `ENV NODE_ENV=production` as the very first line of the `build` stage, before `COPY package.json` / `npm install` ran at all.

### 3. Key Findings
- `NODE_ENV=production` only needs to be set for the `npm run build` process itself (Vite reads it to choose prod vs. dev mode) — it has no legitimate reason to affect what `npm install` installs in a multi-stage build stage whose only job is building, not running, the app.

## Root Cause
`NODE_ENV=production` was scoped to the whole build stage instead of just the build command.

## Prevention / Rule
**Guardrail:** In any multi-stage Dockerfile build stage that both installs dependencies and then builds, set `NODE_ENV=production` (or equivalent) immediately before the build command, never before the install command — and use `npm install --include=dev` explicitly in a build stage regardless, so the behavior doesn't depend on `NODE_ENV`'s value at all. A CI step that actually builds the production image (not just `npm run build` on the host) before merging to `main` would have caught this on day one.

## Solution

### Immediate Fix
Moved `ENV NODE_ENV=production` to immediately before `RUN npm run build`, and changed the install step to `RUN npm install --include=dev`.

### Long-term Fix
Verified locally with `docker build --target prod --build-arg VITE_API_BASE_URL=... frontend/` before trusting it in CI again. No PR-time CI workflow exists yet to build this image automatically on every PR — tracked as a known gap in `docs/deploy/RUNBOOK.md`.

## Prevention
- [x] Configuration changes needed — Dockerfile fixed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None

## References
- `frontend/Dockerfile`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~10 minutes
