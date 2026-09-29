# Staging recreate failed: canonical compose hardcodes prod's container/network/volume names

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Environment:** Staging (erp-vm, 10.50.14.12)
**Severity:** High
**Status:** Resolved

## Summary

After syncing `~/zchpc-erp-staging` to `main`, `docker compose up`
failed with `Conflict. The container name "/zchpc_db" is already in use`
and left the whole staging stack down. The canonical
`docker-compose.yml` hardcodes absolute `container_name`, `networks` and
`volumes` names (`zchpc_*`) identical to the prod stack in `~/zchpc-erp`
on the same host. A VM-local `docker-compose.override.yml` with
staging-scoped names restored isolation; staging is healthy on fresh
images with its original data volume.

## Symptoms

- `docker compose up -d --build api frontend portal` →
  `Error response from daemon: Error when allocating new name: Conflict.
  The container name "/zchpc_db" is already in use`
- All four staging containers ended up stopped/removed; staging fully down.
- Prod (`zchpc_*`) stayed healthy throughout.

## Environment Details

- **Server/Host:** erp-vm (10.50.14.12)
- **Services Affected:** staging stack only
  (`zchpc-erp-staging-{api,frontend,portal,db}-1`)
- **Related Components:** `docker-compose.yml`, `~/zchpc-erp-staging/.env`
  (port remaps 5440/8001/3010/3011), named volumes
- **Time First Observed:** 2026-09-29 during staging rebuild

## Investigation Steps

### 1. Initial Diagnosis

`docker ps` showed prod intact, staging gone. `docker compose config`
showed the merged staging config demanding `container_name: zchpc_api`,
`zchpc_db`, `zchpc_frontend`, `zchpc_portal` and `name: zchpc_network` —
identical to prod.

### 2. Root Cause Analysis

```bash
git log -S 'container_name' --oneline -- docker-compose.yml  # 70cc50a version 1
```

Absolute names exist since `70cc50a`. The old staging dir (pre-sync,
not a git repo) carried a diverged compose *without* `container_name`,
so compose generated project-scoped names (`zchpc-erp-staging-db-1`)
and prod+staging coexisted. Rsyncing canonical `main` over it restored
the absolute names and broke that accidental isolation. Had the name
conflict not fired first, staging would have mounted **prod's named
volumes** (`zchpc_postgres_data`) — same data-loss-adjacent shape.

### 3. Key Findings

- Staging data volume `zchpc-erp-staging_postgres_data` (Aug 27) was never
  mounted by the bad config — verified intact via `docker volume inspect`.
- Ports were never the problem: staging `.env` remaps all host ports.
- Names, not ports, are the collision dimension for same-host stacks.

## Root Cause

Two stacks generated from the same compose file cannot share a host
when that file pins absolute container, network, and volume names.
The staging setup depended on a diverged compose file that masked this;
syncing to canonical `main` removed the mask.

## Prevention / Rule

**Guardrail:** a compose lint check (CI or pre-deploy) asserting that no
`container_name:` or `name:` appears in the shared `docker-compose.yml`
unless it is templated by environment (`${STACK:-zchpc}_api`), so a
second stack on any host gets distinct names by construction.

Fixed absolute names make same-host staging+prod impossible; env-templated
names (like the already-env-driven ports) keep one file working for both.

## Solution

### Immediate Fix

Created VM-local `~/zchpc-erp-staging/docker-compose.override.yml`
(intentionally untracked — environment-specific, like `.env`):

```yaml
services:
  db:       { container_name: zchpc_staging_db }
  api:      { container_name: zchpc_staging_api }
  frontend: { container_name: zchpc_staging_frontend }
  portal:   { container_name: zchpc_staging_portal }
networks:
  erp_network: { name: zchpc_staging_network }
volumes:
  postgres_data: { name: zchpc-erp-staging_postgres_data }  # original data
  api_static:    { name: zchpc-erp-staging_api_static }
  api_media:     { name: zchpc-erp-staging_api_media }
```

Verified via `docker compose config` that no `zchpc_*` prod name remains,
then `docker compose up -d`. All four staging containers healthy;
migrations `portal.0003` + `procurement.0008–0014` applied clean.

### Long-term Fix

- Template the names in the canonical compose (see Guardrail), or ship a
  checked-in `docker-compose.staging.yml` (`-f` overlay) so the isolation
  is versioned instead of VM-local.
- Never rsync canonical files over a diverged staging dir without
  diffing compose/env first.

## Prevention

- [x] Configuration changes needed (override in place on VM)
- [ ] Canonical fix: env-templated names or checked-in staging overlay
- [ ] CI/pre-deploy compose lint for absolute names

## Related Issues

- Staging rebuild report: `reports/ZCHPC-2026-09-29-staging-rebuild-from-main.md`
- Companion incident same session:
  `Frontend_and_UI/ZCHPC-2026-09-29-portal-build-ts2304-missing-vite-env.md`

## References

- `docker compose config` output (staging, post-override)
- Commit introducing absolute names: `70cc50a`

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** ~20 min (diagnose, override, up, verify)
