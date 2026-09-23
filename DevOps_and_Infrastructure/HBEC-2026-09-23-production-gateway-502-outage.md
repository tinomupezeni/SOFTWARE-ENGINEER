# Production Gateway Outage & 502 Bad Gateway

**Date:** 2026-09-23
**Project:** HBEC
**Environment:** Production / Staging (Shared Infra)
**Severity:** Critical
**Status:** Resolved

## Summary
The entire platform (`admin.hbca.tech`, `staging-admin.hbca.tech`, and other domains) went down with `ERR_CONNECTION_REFUSED`, followed by a `502 Bad Gateway` error. This was caused by mistakenly running a default `docker compose up -d` command on the VPS, which used the base `docker-compose.yml` file, skipped the `docker-compose.production.yml` overrides, and automatically deleted the core Caddy reverse proxy as an "orphan" container. 

## Symptoms
- **ERR_CONNECTION_REFUSED:** The reverse proxy was completely removed, stopping all inbound traffic to the domains.
- **HTTP ERROR 502 (Bad Gateway):** After the proxy was restarted, it could not communicate with the backend/frontend services.
- **Caddy Logs Error:** `dial tcp: lookup hbec-admin-frontend on 127.0.0.11:53: server misbehaving`

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** `hbec-gateway` (Caddy reverse proxy), `hbec-admin-frontend`, `hbec-admin-backend`, `hbec-schools-dashboard`, `hbec-schools-backend`
- **Related Components:** Docker Compose Networks (`edge-net`, `app-net`, `hbec-network`)
- **Time First Observed:** 2026-09-23 12:12 (Local)

## Investigation Steps

### 1. Initial Diagnosis
The user reported the connection refusal on `staging-admin.hbca.tech`. We checked `docker ps` and discovered that `hbec-gateway` was missing entirely.

### 2. Root Cause Analysis
- Investigated the previously run deployment command: `docker compose up -d`.
- Checked Docker Compose files and realized `gateway` is only defined in `docker-compose.production.yml`. Because this file wasn't included in the command, Docker treated `hbec-gateway` as an orphan and wiped it.
- After restarting `gateway`, the site returned a 502 error.
- Checked container networks using `docker inspect`: `hbec-gateway` was connected to `hbec-staging_edge-net` and `hbec_edge-net`, but the recreated app containers (like `hbec-admin-frontend`) were incorrectly placed on the isolated `hbec-network`.

```bash
# Commands used for investigation
docker ps -a | grep gateway
grep -A 20 'gateway:' docker-compose.production.yml
docker logs --tail 20 hbec-gateway
docker inspect hbec-admin-frontend | grep -A 10 Networks
docker inspect hbec-gateway | grep -A 10 Networks
```

### 3. Key Findings
- `docker-compose.production.yml` is standalone and dictates the exact networks (`edge-net`, `app-net`) that containers must join to be accessible to the gateway.
- `docker-compose.yml` places containers on `hbec-network`.
- The VPS `.env` file uses a specific `TAG` (e.g., `4af4321`) which caused a registry pull failure when attempting to restore the production config from locally-built `latest` images.

## Root Cause
Executing a manual `docker compose up -d` without specifying `-f docker-compose.production.yml` caused Docker to strip the production networks and delete the shared Caddy proxy (as it considered it an orphan from the base config). When services restarted, they were mapped to the wrong internal Docker network, permanently breaking the proxy's ability to resolve their DNS.

## Prevention / Rule
**Guardrail:** Strictly forbid the use of raw `docker compose up -d` or `docker compose build` commands on the `hbca-vps` server. All deployments must exclusively trigger the predefined deployment shell scripts (e.g., `./deploy.sh` or `./update_staging.sh`) which lock in the correct compose files, profiles, and image tags.

Running raw `docker compose` bypasses the environmental scaffolding required for the production architecture and allows Docker to aggressively delete "orphan" containers that are actually critical infrastructure. 

## Solution

### Immediate Fix
1. Modified the `/opt/hbec/.env` file to set `TAG="latest"` so Docker would recognize the locally built images.
2. Forcibly wiped the conflicting containers to avoid `container_name` collisions.
3. Spun up the entire stack using the explicit production compose file.

```bash
# Commands used to fix
sed -i 's/TAG="4af4321"/TAG="latest"/' /opt/hbec/.env
docker rm -f hbec-schools-dashboard hbec-schools-backend
docker compose -f docker-compose.production.yml --profile workers up -d --remove-orphans
```

### Long-term Fix
- Ensure that agents and operators always use `./deploy.sh` instead of attempting to manually merge or run compose files on the host machine.
- Avoid building images directly on the production host outside of the designated CI/CD pipeline or deployment scripts.

## Prevention
- [ ] Configuration changes needed: None (the script handles it).
- [ ] Monitoring/alerts to add: Alert on `hbec-gateway` container death.
- [ ] Documentation to update: Update `WORKING-PROCESS.md` to explicitly forbid raw `docker compose` usage on remote VPS.
- [ ] Code changes required: None.

## Related Issues
- N/A

## References
- Docker Compose Network Documentation

---

**Resolved By:** Antigravity CLI
**Time to Resolution:** ~15 minutes
