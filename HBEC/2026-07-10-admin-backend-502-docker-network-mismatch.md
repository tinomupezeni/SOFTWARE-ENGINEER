# Admin Backend 502 — Docker Network Mismatch After Container Recreate

**Date:** 2026-07-10
**Project:** HBEC Student Platform
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
After restarting services to apply the Redis sentinel fix, the admin backend container was recreated and landed on the wrong Docker network (`hbec_hbec-network` instead of `hbec_app-net`). The admin frontend's Nginx proxy (which proxies `/api/*` to `admin-backend:8000`) couldn't resolve the `admin-backend` hostname via Docker DNS because they were on different networks. This caused `502 Bad Gateway` for all API requests from the admin frontend (`admin.hbca.tech`).

## Symptoms
- Admin frontend loaded the SPA but all API calls failed with `502 Bad Gateway`
- Console errors: `POST https://admin.hbca.tech/api/auth/login/ 502 (Bad Gateway)`
- Admin frontend's Nginx returned 502 for all `/api/` requests
- Admin backend itself was healthy and serving `/health/` locally (port 8000)
- Caddy gateway (reverse proxy) showed "aborting with incomplete response" to `hbec-admin-frontend:80`

## Environment Details
- **Server/Host:** VPS — 209.209.42.142 (hbec-vps)
- **Services Affected:** admin.hbca.tech frontend → admin-backend API
- **Related Components:** Caddy gateway, admin-frontend Nginx, admin-backend (Uvicorn), Docker networks
- **Time First Observed:** 2026-07-10 ~10:04 UTC (immediately after `docker compose up -d` restart)

## Investigation Steps

### 1. Initial Diagnosis
Checked container status — all reporting healthy. Checked Caddy (gateway) logs — no 502 errors for `/api/` there (Caddy only proxies to admin-frontend). Checked admin-frontend Nginx — the proxy_pass target `admin-backend:8000` was unreachable.

```bash
# Admin backend is healthy internally
docker exec hbec-admin-backend curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/health/
# → 200

# But admin-frontend can't reach it
docker exec hbec-admin-frontend sh -c 'curl -s -o /dev/null -w "%{http_code}" http://admin-backend:8000/health/'
# → 000 (connection refused / DNS failure)
```

### 2. Root Cause Analysis
Inspected Docker networks and found the containers were on different networks.

```bash
# Checked networks
docker inspect hbec-admin-frontend --format '{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}'
# → hbec_app-net, hbec_edge-net

docker inspect hbec-admin-backend --format '{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}'
# → hbec_hbec-network  (WRONG — should be app-net, db-net, hbca-network)

# Docker DNS inside admin-frontend can't resolve admin-backend
docker exec hbec-admin-frontend sh -c 'nslookup admin-backend 127.0.0.11'
# → ** server can't find admin-backend: SERVFAIL
```

### 3. Key Findings
- Admin-backend was only connected to `hbec_hbec-network` (the project default network)
- It should have been on `hbec_app-net` (where the admin-frontend lives) per the production docker-compose
- The `docker compose up -d` recreate did not properly apply the production compose's network overrides
- Even after manually connecting to `app-net`, Docker DNS aliases (`admin-backend` hostname) were not registered — `docker network connect` without `--alias` doesn't set them

## Root Cause
When `docker compose up -d` recreated the admin-backend container (as part of the Redis sentinel fix rollout), the container was attached to the wrong set of networks. The production compose file defines `networks: [app-net, db-net, hbca-network]` for the admin-backend service, but the recreation only attached it to `hbec-network` (from the dev compose file). The network override from `docker-compose.production.yml` was not fully applied during the merge.

## Solution

### Immediate Fix
Connected the admin-backend to the correct networks with proper DNS aliases so the admin-frontend can resolve the hostname.

```bash
# Fix: reconnect with proper aliases
docker network disconnect hbec_app-net hbec-admin-backend
docker network connect --alias admin-backend --alias hbec-admin-backend hbec_app-net hbec-admin-backend

docker network disconnect hbec_db-net hbec-admin-backend
docker network connect --alias admin-backend --alias hbec-admin-backend hbec_db-net hbec-admin-backend

# Verify
docker exec hbec-admin-frontend sh -c 'curl -s -o /dev/null -w "%{http_code}" http://admin-backend:8000/health/'
# → 200
```

### Long-term Fix
Investigate why `docker compose up -d` didn't properly apply the production compose's network overrides. The issue is likely in how Docker Compose merges the `networks` list when the same service is defined in both files. Consider:
- Removing the `admin-backend` service definition from the dev compose (let production compose fully own it)
- Or ensuring both compose files define the same set of networks
- Or pinning the production compose to be the primary config

## Prevention
- [ ] Investigate Docker Compose network merge behavior for services defined in multiple compose files
- [ ] Consider consolidating the admin-backend service definition in a single compose file
- [ ] Add monitoring — alert when any production service returns 5xx responses from the gateway
- [ ] Add a connectivity health check between admin-frontend and admin-backend

## Related Issues
- [2026-07-10: Redis Sentinel Failover — Celery Workers Crash with ReadOnlyError](./2026-07-10-redis-sentinel-failover-readonly-error.md) — the restart that triggered this issue

## References
- Docker Compose network config: `docker-compose.production.yml` lines 397-400
- Admin frontend Nginx config: `proxy_pass http://$admin_backend; set $admin_backend "admin-backend:8000";`

---

**Resolved By:** Tino
**Time to Resolution:** ~15 minutes
