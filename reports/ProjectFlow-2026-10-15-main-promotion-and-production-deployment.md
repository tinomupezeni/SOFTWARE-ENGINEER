# ProjectFlow main promotion and production deployment

**Date:** 2026-10-15
**Project:** ProjectFlow
**Type:** Release / Deployment
**Status:** Completed

## Summary
Promoted the selected backend and frontend staging release lines into their respective `main` branches, preserved the frontend's unrelated local work in a stash, and deployed the resulting release to `restk-vps`. The deployment now uses the production nginx frontend image, has current migrations, and no longer serves a frontend bundle that targets browser localhost.

## Context / Trigger
The previous deployment built from stale or uncontrolled frontend source and used a Vite development Dockerfile, causing an older UI and a `localhost:8000` API regression. The user requested that the updated code first be promoted to `main`, then deployed.

## Scope
Included backend staging promotion with observability and deployment changes, frontend staging promotion retaining the committed API URL fix, production image construction, VPS deployment, and post-deployment verification. Uncommitted frontend UI changes were explicitly excluded and preserved in `stash@{0}`; production hardening warnings and dependency audit findings were not changed.

## Method
Compared branch ancestry and working-tree state, preserved uncommitted work, merged staging into current remote `main` tips, validated both application builds, pushed the promoted branches, ran `deploy.sh`, and verified the running containers, migrations, public endpoints, logs, and served frontend bundle.

## Decisions & Findings
- Backend `main` was behind staging and required promotion; the final backend release is `31e3d5c`.
- Frontend `origin/staging` was selected over the stale frontend line; the final frontend release is `c4f4447`.
- The deployment script was corrected to use `projectflow-hq/Dockerfile.prod`, which builds static assets and serves them with nginx.
- The production bundle contains `https://projectflow.thuthuka.tech/api` and no `localhost:8000`.
- The VPS is still using mutable `latest` image names; immutable artifact tagging remains deferred.

## Changes Made
- Promoted backend staging into `main`, preserving the `SubTaskViewSet` route and adding observability.
- Promoted frontend staging into `main`, retaining the API URL fix.
- Updated `deploy.sh` to build `Dockerfile.prod`.
- Deployed backend, scheduler, database stack, and frontend to `restk-vps`.

## Verification
- Backend `manage.py check`: passed.
- Backend observability tests: 3 passed.
- Frontend `npm ci` and `npm run build`: passed.
- Public frontend: HTTP 200.
- Public API: HTTP 200.
- VPS containers: backend, scheduler, frontend, and PostgreSQL running.
- VPS migrations: no migrations to apply.
- Django deployment checks: only the four previously known HTTPS-cookie/HSTS warnings remain.
- Frontend runtime: nginx serving static assets; bundle loopback check passed.

## Follow-ups / Deferred
- Add immutable commit-based image tags and source labels.
- Add deployment preflight assertions for branch/source identity and required release paths.
- Replace backend Django development server with a production WSGI/ASGI server.
- Address HSTS, SSL redirect, secure session-cookie, and secure CSRF-cookie settings after proxy validation.
- Review the frontend npm audit findings and bundle-size warning.

## References
- `ProjectFlow-2026-10-15-frontend-source-drift-regression.md`
- `ProjectFlow-2026-10-15-frontend-api-loopback-regression.md`
- `ProjectFlow-2026-10-15-incomplete-staging-promotion-merge.md`
- Backend commits `31e3d5c`, `657148b`
- Frontend commit `c4f4447`

---

**Completed By:** Copilot
**Duration:** Same release session
