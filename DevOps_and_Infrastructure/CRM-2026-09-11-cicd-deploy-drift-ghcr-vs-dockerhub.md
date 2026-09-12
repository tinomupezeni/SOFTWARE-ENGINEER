# CI/CD Publishes to GHCR, Production Actually Runs Docker Hub Images From a Directory With No Git Checkout

**Date:** 2026-09-11
**Project:** CRM Professional
**Environment:** Production (restk-vps)
**Severity:** High (CI is silently a no-op for deployment)
**Status:** Workaround Applied for this deploy; root drift not fixed

## Summary
Went to run `deploy.sh` after pushing frontend fixes and discovered the documented deployment path (`deploy.sh` + `docker-compose.deploy.yml` + `.github/workflows/ci.yml`'s `deploy` job) does not match how the CRM is actually deployed on `restk-vps`. A green CI run currently has **zero effect** on what's live.

## Symptoms
- `deploy.sh` expects a git checkout at `~/crm` with `docker-compose.deploy.yml`, pulling images from `ghcr.io/winstonjthinker/crm/{backend,frontend,nginx}`.
- Actual production directory is `~/apps/crm` on `restk-vps` — no `.git`, no `deploy.sh`, no `docker-compose.deploy.yml`. It only has `docker-compose.yml` (+ several `.backup`/`.broken`/`.before-network` variants from a past incident) referencing `tinotenda762/crm-backend:latest` etc. — **Docker Hub, not GHCR** — with local `build:` contexts (`./backend`, `./frontend`) that had no source present to build from.
- CI's `deploy` job (`.github/workflows/ci.yml`) only builds+pushes images to GHCR; nothing in the repo automates getting those images (or any images) onto `restk-vps`.
- The VPS's own GitHub SSH identity (`Rest-creator`) does **not** have access to the private `winstonjthinker/crm` repo (`git clone` → "Repository not found"), so even a corrected deploy script couldn't `git pull` there as-is.

## Root Cause
Deployment tooling (`deploy.sh`, `docker-compose.deploy.yml`, `VPS_DEPLOYMENT_GUIDE.md`, the CI `deploy` job) was written for an idealized "pull prebuilt images from a registry" flow, but the actual production host was set up — and has since been patched through incidents (`fix_crm.sh`, `setup_crm_production.sh`, the 2026-05-07 crash-loop fix) — using a different, ad-hoc "build in place from a local Docker Hub-tagged compose file" flow. The two were never reconciled after whichever migration/restructure happened (see `2026-05-08-monorepo-migration-phase*.md` — those may be part of why this drifted).

## Prevention / Rule
**Guardrail:** a CI job, run after every "deploy" workflow, that SSHes into `restk-vps` and compares the running containers' image digest (`docker inspect --format '{{.Image}}'`) against the digest CI just built and pushed — failing/alerting loudly if they don't match within a few minutes of a green CI run.

This makes "CI passed" and "production actually changed" a provable, checked fact instead of an assumption — which is exactly the assumption that silently broke here and went unnoticed until someone manually tried to deploy.

## Solution (workaround used for this session's deploy)
1. `rsync`'d `frontend/` (excluding `node_modules`, `dist`, `.git`) directly from a local dev checkout to `restk-vps:~/apps/crm-src/frontend` — bypassing the broken GitHub access from the VPS entirely.
2. `ln -sfn ~/apps/crm-src/frontend ~/apps/crm/frontend` so the existing `docker-compose.yml`'s `build: context: ./frontend` resolves.
3. `docker compose -f docker-compose.yml build frontend` then `up -d frontend` (one-shot container that copies `dist/` into the shared `frontend_build` volume) then `up -d nginx`.
4. Verified live: `curl https://crm.restksolutions.co.zw/` serves the new build (new `Combobox-*.js` chunk present), `/health/` returns 200. Backend/db/celery/redis/pgbouncer were never touched — stayed at their pre-existing 4-week uptime.

This only fixed *this deploy*. The underlying drift (CI → GHCR, prod → Docker Hub build-in-place, no VPS git access) is still there.

## Prevention
- [ ] Decide on one source of truth: either point `docker-compose.yml` on the VPS at the GHCR images CI already builds (and give the VPS a working deploy key / update `deploy.sh`'s host+path to match `~/apps/crm`), or drop the GHCR push from CI and instead have CI SSH in and do what was done manually here.
- [ ] Grant `restk-vps`'s GitHub identity (currently `Rest-creator`) read access to `winstonjthinker/crm`, or add a dedicated deploy key, so the VPS can `git pull` directly instead of needing a manual `rsync` from a dev machine.
- [ ] Fix `deploy.sh` / `VPS_DEPLOYMENT_GUIDE.md` to reflect the real path (`~/apps/crm`, not `~/crm`) and the real registry/image names, or fix production to match the documented flow — whichever direction is chosen, update the other so they stop disagreeing.
- [ ] Clean up the stray `docker-compose.yml.backup`/`.broken`/`.before-network`/`docker-compose.backend-fix.yml` files in `~/apps/crm` once the real config is confirmed working, so the next person doesn't have to guess which one is live.

---

**Resolved By:** Claude Code (workaround only)
**Time to Resolution:** ~30 minutes to diagnose + manually redeploy frontend; root drift still open.
