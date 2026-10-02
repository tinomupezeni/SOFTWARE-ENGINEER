# CI workflow failed on every push; 5 of 8 deploy scripts referenced services that don't exist

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, all apps)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
`.github/workflows/deploy.yml` has failed on every single push to `main`
this entire session (confirmed via `gh run list` - every commit shows
`failure`) because its build matrix targets `auth-api`, `catalog-api`,
`order-api`, `brain-api`, `chat-api` - directories that don't exist;
these were consolidated into `store-api` at some earlier point. Three
more root-level scripts (`local-deploy.sh`, `local-deploy.ps1`,
`tese.ps1`) hardcoded the same dead 8-app list, and a fourth
(`local-deploy-enhanced.ps1`, reading from `deployment-config.json`)
encoded an entirely separate, also-abandoned deploy strategy (build
locally, `docker save`/`ssh`/`docker load`) that referenced a
`deploy-v2.sh` which doesn't exist anywhere in the repo.

## Symptoms
- Every `git push origin main` this session produced a red X on GitHub
  Actions - confirmed via `gh run list --workflow=deploy.yml`, which
  showed `failure` on all 5 most recent runs at the time of
  investigation, each completing in under 25 seconds (failing at the
  first build step for a missing Dockerfile path).
- Real deploys were already happening entirely by hand (manual SSH +
  `docker compose build` on the VPS) all session, so this had zero
  functional impact beyond the noise - but it's exactly the kind of
  artifact that makes the codebase look more service-fragmented than it
  actually is.

## Environment Details
- **Server/Host:** GitHub Actions (CI) and the VPS deploy directory
  (`/home/winstontino/apps/tese-marketplace`)
- **Services Affected:** CI/CD pipeline only - no production service
  impact
- **Related Components:** `.github/workflows/deploy.yml`,
  `local-deploy.sh`, `local-deploy.ps1`, `local-deploy-enhanced.ps1`,
  `tese.ps1`, `deployment-config.json`
- **Time First Observed:** 2026-10-02 (the workflow had evidently been
  failing long before this session - confirmed failing on commits made
  earlier the same day, before this specific investigation)

## Investigation Steps

### 1. Initial Diagnosis
User's complaint that the codebase "feels like" multiple services
prompted re-checking deploy tooling that had been flagged-but-deferred in
an earlier session (noted as broken in
`DevOps_and_Infrastructure/tese-marketplace-2026-09-28-ci-deploy-scripts-stale-microservice-split.md`
but not acted on at the time).

### 2. Root Cause Analysis
```bash
gh run list --workflow=deploy.yml --limit 5
# every row: completed / failure, ~20s each
```
Read `.github/workflows/deploy.yml` directly: its `strategy.matrix.app`
list and `file: apps/${{ matrix.app }}/Dockerfile` build step reference 5
directories that don't exist. Its `deploy:` job also assumes a completely
different deploy strategy (push built images to `ghcr.io`, SSH to the VPS
and `docker compose pull`) than what's actually used (`deploy-vps.sh`:
`git pull` + `docker compose build` directly on the VPS).

Checked every other root-level `.sh`/`.ps1` deploy script for the same
dead app list:
```bash
grep -n "auth-api\|catalog-api\|order-api\|brain-api\|chat-api" *.sh *.ps1
```
Found the same hardcoded list in `local-deploy.sh`, `local-deploy.ps1`,
and `tese.ps1`. `local-deploy-enhanced.ps1` had no hardcoded list (it
reads `deployment-config.json`'s `apps` array dynamically) but that
config file had the same stale list, and the script also referenced
`deploy-v2.sh`, confirmed via `find` to not exist anywhere in the repo -
so it was non-functional independent of the stale service names.

### 3. Key Findings
- `deploy-vps.sh`, `deploy.ps1`, `deploy-monolith.ps1`, and
  `docker-compose.vps.yml` were independently confirmed correct and are
  what's actually been used for every deploy this session (direct SSH,
  `docker compose build` on the VPS from git source).
- `master-smoke-test.ps1`, `rebuild-frontend.ps1`, and
  `verify-frontend.ps1` were checked and have no stale references - kept
  as-is.
- Rebuilding `deploy.yml` into *real*, working, auto-deploying CI/CD is a
  meaningfully bigger and riskier decision (requires verifying
  `SSH_HOST`/`SSH_USER`/`SSH_PRIVATE_KEY` GitHub secrets are even
  configured, and choosing an actual auto-deploy strategy) than simply
  removing a broken, redundant workflow - raised explicitly to the user
  rather than assumed.

## Root Cause
Deploy tooling was never updated when the backend was consolidated from
8 planned microservices into one `store-api` monolith - 5 of 8 scripts
(plus CI) kept referencing the old topology indefinitely, with no
automated check (like CI itself, ironically) to catch drift between
deploy scripts and the actual `apps/` directory structure.

## Prevention / Rule
**Guardrail:** Exactly one deploy path should exist per environment.
When more than one script claims to deploy the same app, that's itself a
defect regardless of which one is currently correct - the extra ones
will inevitably drift and start lying about the architecture, same as
happened here. Before adding a new deploy script, check whether an
existing one already does the job.

## Solution

### Immediate Fix
Removed (per explicit user decision on the CI workflow, documented in
the companion report):
- `.github/workflows/deploy.yml` - disabled rather than rebuilt into
  real auto-deploy CI/CD, which is separate, larger scope.
- `local-deploy.sh`, `local-deploy.ps1`, `tese.ps1` - hardcoded the dead
  app list, redundant with the confirmed-working trio.
- `local-deploy-enhanced.ps1`, `deployment-config.json` - a second,
  independently-abandoned deploy strategy, already non-functional
  (missing `deploy-v2.sh`).

Verified no other file in the repo references any of the removed
scripts/config (`grep -rl` across `*.md`/`*.json`/`*.yml`/`*.ps1`/`*.sh`,
excluding this agent's own local tool-permission cache).

```bash
git rm .github/workflows/deploy.yml local-deploy.sh local-deploy.ps1 \
  local-deploy-enhanced.ps1 tese.ps1 deployment-config.json
```

### Long-term Fix
If real CI/CD (auto-deploy on push) is wanted later, build it against the
actual 3-app structure and the actual deploy strategy (build on VPS via
SSH), as its own dedicated piece of work - not by resurrecting any of the
removed scripts.

## Prevention
- [x] Code changes required (done this session)
- [ ] Decide whether to build real CI/CD later (deferred, user's call)

## Related Issues
- `DevOps_and_Infrastructure/tese-marketplace-2026-09-28-ci-deploy-scripts-stale-microservice-split.md`
  (this issue flagged and deferred in an earlier session; this entry is
  where it was finally acted on)
- `reports/tese-marketplace-2026-10-02-foundations-alembic-and-dead-code-cleanup.md`
- `Architecture_and_Design/tese-marketplace-2026-10-02-dead-smart-orchestrator-proxy-layer.md`
  (the same abandoned split, found again in application code rather than
  deploy config)

## References
- `deploy-vps.sh`, `deploy.ps1`, `deploy-monolith.ps1`,
  `docker-compose.vps.yml` (the scripts that remain, confirmed correct)

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~15 minutes from re-investigation to verified removal
