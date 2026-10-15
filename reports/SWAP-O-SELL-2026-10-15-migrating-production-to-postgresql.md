# Migrating Swap-O-Sell Production to PostgreSQL

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Architecture Decision / Production Configuration
**Status:** Completed

## Summary
Swap-O-Sell production was migrated from its initial SQLite fallback to an
isolated PostgreSQL 16 service on `restk-vps`. PostgreSQL now runs without a
host port on a private Compose network, while the existing Caddy ingress and
other VPS tenants remain unchanged.

## Context / Trigger
The initial deployment used SQLite because the production `DATABASE_URL` was
empty. The user requested PostgreSQL for production persistence and concurrent
marketplace workloads.

## Scope
Included the production Compose topology, VPS environment configuration,
backend database selection, deployment documentation, and live verification.
The existing SQLite volume was not deleted because it is a historical rollback
artifact and the deployment contained no application records requiring export.
No other VPS database containers or credentials were changed.

## Method
Inspected the repository and VPS database topology, checked the existing
Swap-O-Sell SQLite volume for application records, added a dedicated PostgreSQL
service and private network, deployed the exact committed source, and verified
the running Django database vendor and health endpoint.

## Decisions & Findings
- Use a dedicated `postgres:16-alpine` container and named volume for
  Swap-O-Sell isolation.
- Require `DATABASE_URL`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
  `POSTGRES_DB` in the production environment rather than permitting a silent
  SQLite fallback.
- Keep PostgreSQL on `swaposell-internal`; only the backend joins that network,
  and no host port is published.
- The previous SQLite database had zero marketplace users, products, and
  conversations, so no data migration was necessary.

## Changes Made
- Updated `docker-compose.production.yml` with the isolated PostgreSQL service,
  healthcheck, private network, persistent volume, and backend dependency.
- Updated `deploy/README.md` with required PostgreSQL variables and retention
  guidance for the old SQLite volume.
- Configured the VPS-only `.env.production` with a generated database password.
- Deployed commit `6822bb3` through the manual source-streaming path.

## Verification
- `swaposell-db-1` is healthy.
- `swaposell-backend-1` is healthy.
- Django reports `connection.vendor == "postgresql"`.
- PostgreSQL reports database `swaposell` and user `swaposell`.
- `/api/health/` returns `{"ok": true, "service": "swap-o-sell"}`.
- Existing tenant Compose projects and host ports were not modified.

## Follow-ups / Deferred
- Add scheduled `pg_dump` backups and a restore drill.
- Remove the unused SQLite volume after the PostgreSQL retention window.
- Resolve the GitHub Actions billing restriction so the automated deployment
  path can execute instead of the manual source-streaming path.
- Add PostgreSQL resource limits after observing production workload.

## References
- `Database_and_State/SWAP-O-SELL-2026-10-15-production-sqlite-database.md`
- `/home/shadowe/Projects/swap-o-sell/docker-compose.production.yml`
- `/home/shadowe/Projects/swap-o-sell/deploy/README.md`
- `/home/shadowe/Projects/SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/6. Database Engineering.md`
- `/home/shadowe/Projects/SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/10. Deployment And Maintenance.md`

---

**Completed By:** Copilot
**Duration:** Same deployment session
