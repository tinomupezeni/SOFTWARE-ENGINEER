# CI workflow and most deploy scripts still target a removed 8-microservice split

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture)
**Environment:** Production (VPS) / CI (GitHub Actions)
**Severity:** High
**Status:** Investigating (found, not yet fixed — reported to user, awaiting direction)

## Summary
The repo was consolidated from an 8-microservice split (`auth-api`, `catalog-api`,
`order-api`, `store-api`, `brain-api`, `chat-api`, plus the two frontends) into a
3-app modular monolith (`apps/store-api` as a "smart orchestrator" absorbing
auth/catalog/orders/brain/chat as internal modules, `apps/customer-store`,
`apps/admin-dashboard`). Only `deploy-vps.sh`, `deploy.ps1`, `deploy-monolith.ps1`,
and `docker-compose.vps.yml` were updated to match. Five other deploy-related
files were never updated and still reference the five now-nonexistent services.

## Symptoms
- `.github/workflows/deploy.yml` triggers automatically on every push to `main`
  and runs a build matrix over 8 apps; 5 of the 8 (`auth-api`, `catalog-api`,
  `order-api`, `brain-api`, `chat-api`) point at `apps/<name>/Dockerfile` paths
  that don't exist, so those matrix jobs fail on every single push.
- `local-deploy.sh` would fail immediately trying to build
  `apps/auth-api/Dockerfile` (nonexistent), and separately tries to scp/run a
  `deploy-v2.sh` that doesn't exist anywhere in the repo.
- `tese.ps1` (the documented main deploy CLI per its own `.SYNOPSIS`) and
  `local-deploy.ps1` both hardcode the same stale 8-service list.
- `local-deploy-enhanced.ps1` reads its app list from `deployment-config.json`,
  which also still lists the 5 dead services — so it inherits the same failure
  mode indirectly.

## Environment Details
- **Server/Host:** GitHub Actions (CI) and the production VPS
  (159.198.42.231, `winstontino@`)
- **Services Affected:** CI/CD pipeline; local/VPS deploy tooling
- **Related Components:** `.github/workflows/deploy.yml`, `local-deploy.sh`,
  `local-deploy.ps1`, `local-deploy-enhanced.ps1`, `tese.ps1`,
  `deployment-config.json`
- **Time First Observed:** 2026-09-28, when asked to check for a deploy script
  as part of an unrelated frontend redesign session

## Investigation Steps

### 1. Initial Diagnosis
User asked to check for a deploy script. `ls`/`find` turned up 9 deploy-related
scripts plus a GitHub Actions workflow and a `deployment-config.json`.

### 2. Root Cause Analysis
```bash
ls apps/                          # only: admin-dashboard, customer-store, store-api
grep -n "auth-api\|catalog-api\|order-api\|brain-api\|chat-api" \
  .github/workflows/deploy.yml local-deploy.sh tese.ps1 local-deploy.ps1 \
  deployment-config.json
```
Confirmed every one of those files still lists the 5 removed services; cross-
referenced against the real `apps/` directory and `docker-compose.vps.yml`
(which is correct) to confirm which side had drifted.

### 3. Key Findings
- `docker-compose.vps.yml` and the 3 scripts built directly around it
  (`deploy-vps.sh`, `deploy.ps1`, `deploy-monolith.ps1`) are correct and
  current.
- The CI workflow is the highest-severity instance since it runs
  unattended on every push, not just when someone manually invokes a
  deploy script.

## Root Cause
When the backend was consolidated from 8 services into the `store-api`
monolith, the compose file and the 3 VPS-side scripts built around it were
updated, but the CI workflow, the local-build scripts, and the shared
`deployment-config.json` were not — a partial migration with no single
source of truth for "which apps exist," so several files silently kept
describing the pre-consolidation architecture.

## Prevention / Rule
**Guardrail:** There should be exactly one source of truth for "what apps this
repo builds and deploys" — `deployment-config.json` — and every deploy script
(including the CI workflow) should read its app list from it rather than
hardcoding a matrix or array. A CI step that diffs the configured app list
against `ls apps/` (failing the build on mismatch) would have caught this
the moment `apps/auth-api` etc. were deleted.

This closes the gap because a structural consolidation (removing/renaming an
app directory) becomes a build-breaking, visible CI failure immediately,
instead of a silent drift that only surfaces when someone happens to read
the deploy scripts.

## Solution

### Immediate Fix
Not yet applied — reported to the user with the two options (fix the stale
scripts/workflow now, or continue using the known-good `deploy-monolith.ps1`
/ `deploy-vps.sh` path). Awaiting direction before editing CI/deploy
infrastructure, since that's a higher-blast-radius change than the frontend
work this session was otherwise doing.

### Long-term Fix
- Update `deployment-config.json` to the real 3-app list.
- Point `.github/workflows/deploy.yml`'s matrix, `local-deploy.sh`'s `APPS`
  array, and `tese.ps1`/`local-deploy.ps1`'s service lists at that config
  (or otherwise regenerate them from it) instead of hardcoding.
- Delete the dangling reference to `deploy-v2.sh` in `local-deploy.sh` (file
  doesn't exist in the repo at all).

## Prevention
- [ ] Configuration changes needed (`deployment-config.json` app list)
- [ ] CI check to add (app-list-vs-`apps/`-directory consistency check)
- [ ] Documentation to update (which deploy script is canonical)
- [ ] Code changes required (`.github/workflows/deploy.yml`, `local-deploy.sh`,
      `tese.ps1`, `local-deploy.ps1`)

## Related Issues
- Found during the same session as
  `reports/tese-marketplace-2026-09-28-farmer-self-listing.md` and the
  ongoing Apple-HIG customer-store redesign, but unrelated to either —
  discovered only because the user asked to check for a deploy script.

## References
- `.github/workflows/deploy.yml`
- `docker-compose.vps.yml` (the correct reference)
- `deployment-config.json`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni) — found and reported, not yet fixed
**Time to Resolution:** N/A (investigation only; awaiting user direction on the fix)
