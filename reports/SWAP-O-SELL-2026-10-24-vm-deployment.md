# Swap-O-Sell VM Deployment

**Date:** 2026-10-24
**Project:** Swap-O-Sell
**Type:** Deployment / Infrastructure Setup
**Status:** Completed

## Summary
Swap-O-Sell was deployed to the dedicated `mywealth-vm` host using Docker Compose without changing the existing Apache service or requiring the production domain. The exact `main` commit was transferred, production images were built on the VM, PostgreSQL migrations ran, and the backend, storefront, and admin interfaces passed HTTP smoke checks on temporary host ports.

## Context / Trigger
The requested deployment target was `mywealth-vm`. Initial inspection found no Docker runtime, an existing host Apache listener on port 80, host PostgreSQL 14, and no configured production domain or Caddy edge.

## Scope
Included VM Docker provisioning, exact source transfer, temporary Compose port exposure, generated VM-local secrets, image builds, database initialization, migrations, service startup, and HTTP smoke verification. Domain DNS, TLS, Apache replacement, Caddy provisioning, external payment credentials, WhatsApp credentials, and production data migration were explicitly excluded.

## Method
The target was inspected before changes. Docker Engine and Compose were installed by the operator. The exact repository `main` commit was archived and transferred to the VM, avoiding unverified source drift. A VM-only Compose override exposed backend port 8000, storefront port 8080, and admin port 5174 while keeping PostgreSQL private. Health, migration, artifact, storage, and HTTP checks were then run.

## Decisions & Findings
- The host is dedicated, so Docker provisioning was approved.
- Apache on port 80 was left untouched; temporary application ports were used.
- The Compose-managed PostgreSQL 16 service was used instead of the existing host PostgreSQL 14.
- The production healthcheck required a VM-specific `Host` header because the domain was intentionally deferred.
- The deployment is reachable at `http://10.50.23.166:8080/`, admin at `http://10.50.23.166:5174/`, and direct API at `http://10.50.23.166:8000/api/health/`.

## Changes Made
- Installed Docker Engine 29.9.2, Compose v5.6.1, and created `proxy-tier` on `mywealth-vm`.
- Transferred commit `6822bb342bc75df2803a992a0373ab00224427b8`.
- Created VM-local `.env.production` with generated Django and PostgreSQL secrets.
- Created VM-local `compose.vm.yml` for temporary port exposure and health probing.
- Started `swaposell-db-1`, `swaposell-backend-1`, `swaposell-frontend-1`, and `swaposell-admin-1`.
- Recorded the release identity in `RELEASE_SHA`.

## Verification
- Docker and Compose commands succeeded after reconnecting the SSH session.
- All Django migrations applied successfully; `showmigrations --plan` ended with all entries marked `[X]`.
- Backend container reported healthy.
- PostgreSQL container reported healthy.
- `GET /api/health/` returned HTTP 200 and `{"ok": true, "service": "swap-o-sell"}`.
- Storefront returned HTTP 200 and proxied `/api/health/` successfully.
- Admin frontend returned HTTP 200.
- Built image digests were recorded for backend, frontend, and admin.
- Persistent media and PostgreSQL Docker volumes were present.

## Follow-ups / Deferred
- Configure DNS and TLS before public production traffic.
- Replace Apache or configure a deliberate reverse-proxy path for port 80/443.
- Remove temporary host port exposure once the edge proxy is ready.
- Add authenticated GitHub pull/deploy or retain the exact-archive transfer method.
- Configure and verify payment, WhatsApp, backup, monitoring, and rollback procedures.
- Review the bundled frontend fallback localhost strings; the active API smoke path used `/api/` successfully.

## References
- `DevOps_and_Infrastructure/SWAP-O-SELL-2026-10-24-vm-missing-docker.md`
- `DevOps_and_Infrastructure/SWAP-O-SELL-2026-10-24-vm-topology-mismatch.md`
- `/home/shadowe/Projects/swap-o-sell/docker-compose.production.yml`
- `/home/shadowe/Projects/swap-o-sell/deploy/deploy.sh`

---

**Completed By:** Copilot
**Duration:** Approximately 30 minutes
