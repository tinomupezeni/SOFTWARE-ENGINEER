# Production SQLite Database for Swap-O-Sell

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The initial Swap-O-Sell VPS deployment uses a persistent SQLite volume because
`DATABASE_URL` is empty. Production should use PostgreSQL for transactional
concurrency, operational backups, and safer growth on the shared VPS.

## Symptoms
- The production backend is configured to fall back to SQLite.
- The user identified that the production database should be PostgreSQL instead.
- The deployment currently has no Swap-O-Sell-specific PostgreSQL service or
  database URL.

## Environment Details
- **Server/Host:** `restk-vps` (`159.198.42.231`)
- **Services Affected:** `swaposell-backend-1`, deployment configuration
- **Related Components:** Docker Compose, Django database settings, persistent
  database volumes
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the production Compose file, VPS environment configuration, and
running containers.

### 2. Root Cause Analysis
The production Compose file passes an optional `DATABASE_URL`; when it is
empty, Django uses its SQLite fallback and persists the database in the
`swaposell_swaposell-backend-db` volume.

```bash
docker compose --project-name swaposell --env-file .env.production \
  -f docker-compose.production.yml config
docker ps
```

### 3. Key Findings
- The production `.env.production` has an empty `DATABASE_URL`.
- The backend Compose service mounts a SQLite database volume.
- The VPS already runs PostgreSQL containers for other tenants, but their
  database ownership and credentials must not be reused.
- Swap-O-Sell needs an isolated PostgreSQL database and persistent volume.

## Root Cause
SQLite was intentionally selected as an initial low-volume deployment default,
but that default is unsuitable for the requested production operating model.

## Prevention / Rule
**Guardrail:** Production Compose configuration must require a PostgreSQL
`DATABASE_URL` and must not expose a SQLite fallback.

Making the production database URL mandatory causes deployment validation to fail
before containers start if PostgreSQL is not configured.

## Solution

### Immediate Fix
Pending: add an isolated PostgreSQL service, migrate the existing SQLite data,
and deploy the backend against PostgreSQL.

### Long-term Fix
Keep PostgreSQL data in its own named volume, use a dedicated Swap-O-Sell
database user, and add database readiness plus migration checks to deployment
verification.

## Prevention
- [ ] Require PostgreSQL in production Compose configuration
- [ ] Add PostgreSQL readiness and migration checks
- [ ] Document backup and restore commands
- [ ] Remove the production SQLite volume after migration verification

## Related Issues
- `SWAP-O-SELL-2026-10-15-vps-deployment-and-github-actions.md`

## References
- `/home/shadowe/Projects/swap-o-sell/docker-compose.production.yml`
- `/home/shadowe/Projects/swap-o-sell/backend/swaposell/settings.py`
- `/home/shadowe/Projects/SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/6. Database Engineering.md`
- `/home/shadowe/Projects/SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/10. Deployment And Maintenance.md`

---

**Resolved By:** Pending
**Time to Resolution:** Pending
