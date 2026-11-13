# LEC Biotec production deployment verification

**Date:** 2026-11-13
**Project:** LEC Biotec
**Type:** Deployment / Verification
**Status:** Completed

## Summary
Inspected the repository deployment path, synchronized the local branch with
GitHub `main`, corrected cross-service version propagation, deployed commit
`3ff367d` to `tino-vps`, and verified the production stack and public user
journeys.

## Context / Trigger
Production was running a newer GitHub commit than the local checkout. The
request was to synchronize the code, identify the deployment script, deploy the
updated code, and test the deployed version thoroughly.

## Scope
Included deployment script review, production Compose/Docker build, migration
execution, runtime artifact identity, service health, public API checks,
frontend/admin asset checks, and browser smoke journeys. Payment-provider
transactions, authenticated staff workflows, and customer order placement were
excluded because they require credentials and business data.

## Method
Reviewed `deploy.sh`, `docker-compose.yml`, `Dockerfile`, and `nginx.conf`.
Verified the source commit and clean worktree, ran the deployment script through
the configured `vps-tino` Docker context, then checked remote container state,
image identity, migrations, public HTTPS endpoints, assets, forbidden host
values, and Playwright browser journeys.

## Decisions & Findings
- The deployment path is `./deploy.sh`; it builds locally and deploys through
  Docker context `vps-tino` to `administrator@93.127.143.153`.
- The deployment initially had a version-identity gap: only the API received
  `APP_VERSION`. Worker and beat were corrected before deployment.
- The production catalogue endpoint currently returns an empty item set with
  empty facets. This is a data-state observation, not a deployment failure.
- Anonymous admin/API requests return expected 403 responses.

## Changes Made
- Published `0cf90f7` to GitHub `main` with the synchronized local updates.
- Published `3ff367d` with `APP_VERSION` propagation for Celery worker and beat.
- Deployed `3ff367d` using `./deploy.sh`.

## Verification
- Deployment build completed successfully.
- Public shallow health: HTTP 200, `{"status":"alive"}`.
- Public deep health: HTTP 200, version `3ff367d`; database, cache, and storage
  all reported `up`.
- API, worker, and beat all reported `APP_VERSION=3ff367d`.
- Migration container exited with code 0 and reported no migrations pending.
- Storefront and admin JavaScript/CSS assets returned HTTP 200.
- Storefront, `/products`, `/catalogue`, and `/admin/` rendered in headless
  Chromium.
- Anonymous 403 responses were accepted only for the expected auth/session
  endpoints.
- Recent API logs contained no error, exception, traceback, or critical entries.
- Worktree remained clean after deployment.

## Follow-ups / Deferred
- Add automated configuration-parity verification for `APP_VERSION` across all
  application services.
- Investigate the empty production catalogue before customer commerce testing.
- Run authenticated admin and checkout journeys when test credentials and safe
  production test data are available.

## References
- `deploy.sh`
- `docker-compose.yml`
- `Dockerfile`
- `nginx.conf`
- `LEC-2026-11-13-worker-app-version-drift.md`

---

**Completed By:** Copilot
**Duration:** Same deployment session
