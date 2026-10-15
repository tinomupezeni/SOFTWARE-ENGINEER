# Swap-O-Sell VPS deployment and GitHub Actions setup

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Deployment / Release Engineering
**Status:** Completed with external follow-up

## Summary
Swap-O-Sell was deployed to `restk-vps` as an isolated Docker Compose project and routed through the existing Coolify-managed Caddy proxy. A repeatable deployment script and GitHub Actions workflow were added for future automatic deployments without publishing new host ports or affecting adjacent Docker projects.

## Context / Trigger
The user requested a VPS deployment after confirming whether an existing version was present, a repeatable deployment script, GitHub Actions auto-deployment suitable for a student account, protection of other running images and ports, and a Caddy route for `swaposell.restksolutions.co.zw`.

## Scope
Included VPS discovery, isolated Compose production configuration, admin production image conversion, Caddy routing, deploy-key setup, GitHub Actions workflow, first deployment, and verification. PostgreSQL migration and DNS management were excluded because no dedicated database credentials or DNS provider access were available.

## Method
Inspected the VPS read-only before mutation, confirmed no existing Swap-O-Sell project or images, mapped the active Caddy container and `proxy-tier` network, added deployment artifacts, validated locally, performed a manual first deployment, and verified containers, internal routes, Caddy configuration, and host-port isolation.

## Decisions & Findings
- No existing Swap-O-Sell deployment was found on the VPS.
- The production project uses Compose project name `swaposell` and persistent named volumes.
- Backend, storefront, and admin containers publish no host ports; Caddy reaches them over `proxy-tier`.
- The main domain routes `/api/*` to Django, `/admin/*` to the admin frontend, and all other paths to the storefront.
- The private GitHub repository is transferred by the Action over SSH rather than cloned from the VPS.
- A dedicated deploy key was installed for the GitHub Actions user and repository secrets were configured.
- GitHub Actions is currently blocked before runner startup by the account billing/spending-limit status.
- The domain DNS name does not currently resolve from the VPS; an A record is required before public HTTPS can complete.

## Changes Made
- Added `docker-compose.production.yml`.
- Converted the admin container from a Vite development server to a static Nginx image.
- Added `admin/nginx.conf` and `/admin/` Vite base configuration.
- Added `deploy/deploy.sh`, Caddy route fragment, and deployment README.
- Extended `.github/workflows/ci.yml` with admin validation and SSH deployment.
- Inserted the managed Swap-O-Sell block into `/home/winstontino/core/Caddyfile`.
- Installed the VPS-only `.env.production` without committing it.

## Verification
- Storefront production build passed.
- Admin typecheck and production build passed.
- Production Compose configuration validated.
- VPS backend migrations completed.
- VPS backend health endpoint passed with the production host header.
- All three Swap-O-Sell containers are running and isolated.
- No Swap-O-Sell host ports are published.
- Caddy configuration validation passed and reload completed.
- Existing Docker projects remained running and unchanged.
- Internal backend, storefront, and admin routes responded over `proxy-tier`.

## Follow-ups / Deferred
- Create DNS A record `swaposell.restksolutions.co.zw -> 159.198.42.231`.
- Resolve GitHub billing/spending-limit status and verify a successful automated deploy run.
- Consider migrating production persistence from SQLite to a dedicated PostgreSQL database before higher write volume.
- Add public HTTPS smoke verification after DNS propagation.

## References
- `docker-compose.production.yml`
- `deploy/deploy.sh`
- `deploy/README.md`
- `deploy/caddy/swaposell.caddy`
- `SWAP-O-SELL-2026-10-15-production-healthcheck-host-mismatch.md`
- `SWAP-O-SELL-2026-10-15-github-actions-billing-block.md`

---

**Completed By:** Copilot
**Duration:** Same session
