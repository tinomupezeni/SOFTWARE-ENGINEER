# Nginx Upstream Hostname Mismatch (502 Bad Gateway)

**Date:** 2026-10-08
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The Nginx reverse proxy was returning a 502 Bad Gateway for all frontend requests after deployment because its upstream configurations were hardcoded to the service names from the development `docker-compose.yml` instead of the production `docker-compose.prod.yml`.

## Symptoms
- After running the staging deployment script, all web traffic to the staging site returned standard Nginx 502 Bad Gateway errors.
- The containers for the backend and frontend were running successfully and not crashing.

## Environment Details
- **Server/Host:** Staging VM (10.50.1.37)
- **Services Affected:** `nginx`, `frontend_client`, `frontend_admin`
- **Related Components:** `nginx/nginx.conf`, `docker-compose.prod.yml`
- **Time First Observed:** 2026-10-08

## Investigation Steps

### 1. Initial Diagnosis
Viewed the logs for the Nginx container, which showed successful startup but no immediate errors. Checked the raw `nginx.conf` mounted into the container.

### 2. Root Cause Analysis
Discovered that `nginx.conf` had `proxy_pass http://frontend-client-v2:80;` and `proxy_pass http://frontend-admin-v2:80;`.
However, the production compose file (`docker-compose.prod.yml`) defines these services as `frontend_client` and `frontend_admin`. The old `docker-compose.yml` (used for dev) defined them with the `-v2` suffix. This caused Nginx to fail DNS resolution for the upstreams in the Docker network.

### 3. Key Findings
- Nginx configuration was coupled to the development compose file instead of being unified or matching the production compose file.
- The previous deployment worked only because the old orphaned development containers (`tesc-frontend-client-v2-1`) were still running on the same docker network and handling requests.

## Root Cause
Nginx was configured to point to service names (`frontend-client-v2`) that were only defined in the development compose file, not the production compose file (`frontend_client`).

## Prevention / Rule
**Guardrail:** Service names across all docker-compose files (dev, staging, prod) MUST be identical for corresponding components (e.g., `frontend_client` must be `frontend_client` everywhere). Avoid appending environment suffixes like `-v2` to service definitions inside compose files.

This prevents Nginx configurations (which rely on Docker's internal DNS resolving service names) from breaking when moving between environments.

## Solution

### Immediate Fix
Updated `nginx.conf` to use the correct service names defined in `docker-compose.prod.yml`.

```bash
sed -i 's/frontend-client-v2/frontend_client/g' nginx/nginx.conf
sed -i 's/frontend-admin-v2/frontend_admin/g' nginx/nginx.conf
```
Restarted Nginx on the staging VM.

### Long-term Fix
Harmonize the service names in `docker-compose.yml` to match `docker-compose.prod.yml` so they are identical.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 5m
