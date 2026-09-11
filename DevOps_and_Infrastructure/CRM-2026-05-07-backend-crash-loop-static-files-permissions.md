# Backend Crash Loop - Static Files Permission Error

**Date:** 2026-05-07
**Project:** CRM Professional
**Environment:** Production (VPS)
**Severity:** Critical
**Status:** Resolved

## Summary
The CRM application at https://crm.restksolutions.co.zw was completely down with `ERR_INVALID_RESPONSE`. The backend container was stuck in a crash loop, preventing nginx from starting and serving requests.

## Symptoms
- Site returning `ERR_INVALID_RESPONSE` in browser
- Backend container status: `Restarting (1) 12 seconds ago`
- Nginx container status: `Created` (never started)
- Frontend container: `Exited (0)`
- Celery workers: `Created` (never started)

## Environment Details
- **Server/Host:** 159.198.42.231 (VPS)
- **Services Affected:** All CRM services
- **Related Components:**
  - Backend (Django + Gunicorn)
  - Nginx (reverse proxy)
  - Caddy (external reverse proxy)
  - Docker volumes (static_files)
- **Time First Observed:** 2026-05-07 ~09:00 UTC
- **Downtime:** ~1.5 hours

## Investigation Steps

### 1. Initial Diagnosis
Ran diagnostics from deployment script:

```bash
cd "C:\Users\Dell\Documents\projects\CRM\crm"
powershell -ExecutionPolicy Bypass -File ".\scripts\crm.ps1" diagnose
```

**Findings:**
- Backend: `Restarting (1) 12 seconds ago`
- All other containers either `Created` or `Exited`
- Database healthy, Redis healthy, PGBouncer healthy

### 2. Root Cause Analysis
Checked backend logs via SSH:

```bash
ssh winstontino@159.198.42.231 "cd /home/winstontino/apps/crm && docker compose logs --tail=50 backend"
```

**Key Error:**
```python
PermissionError: [Errno 13] Permission denied: '/app/staticfiles/admin'
```

Full traceback showed:
- `collectstatic` command failing in entrypoint script
- Container running as user `app` (UID 1000)
- Docker volume owned by root with restrictive permissions
- Entrypoint script had `set -e`, causing immediate exit on error

### 3. Additional Issues Found

**Network Configuration Problem:**
```bash
docker network inspect proxy-tier
```
Found that nginx container was NOT connected to `proxy-tier` network (Caddy's network), preventing external routing even if backend was healthy.

**Pending Migrations:**
```
Your models in app(s): 'quotations' have changes that are not yet reflected in a migration
```
Not blocking, but noted for future.

## Root Cause

**Three interrelated issues:**

1. **Static Files Volume Permissions** (Primary)
   - Docker volume `crm_static_files` owned by root with no write access for UID 1000
   - Backend container runs as non-root user `app` for security
   - `collectstatic` command in entrypoint.prod.sh fails with permission denied

2. **Entrypoint Script Design Flaw**
   - Script used `set -e` which exits on ANY error
   - Despite having `|| echo "Warning..."` fallback for collectstatic
   - The `set -e` takes precedence, causing container to crash loop

3. **Docker Network Misconfiguration**
   - Nginx container only connected to `crm_crm_internal`
   - Missing connection to `proxy-tier` network where Caddy resides
   - Caddy couldn't route external traffic to nginx

## Solution

### Immediate Fix (Applied)

**1. Fixed Volume Permissions:**
```bash
ssh winstontino@159.198.42.231
cd /home/winstontino/apps/crm

# Use temporary container to fix permissions
docker run --rm -v crm_static_files:/staticfiles alpine sh -c 'chmod -R 777 /staticfiles'
```

**2. Collected Static Files with Root User:**
```bash
# Stop all containers
docker compose down

# Restore docker-compose.yml
# (scp from local machine)

# Start infrastructure
docker compose up -d db pgbouncer redis

# Collect static files as root
docker compose run --rm --user root backend python manage.py collectstatic --noinput
# Result: 154 static files copied

# Start all services
docker compose up -d
```

**3. Connected Nginx to Caddy Network:**
```bash
# Connect nginx to proxy-tier network
docker network connect --alias crm-nginx proxy-tier crm-nginx-1

# Verify
docker network inspect proxy-tier --format '{{range .Containers}}{{.Name}} {{end}}' | grep crm-nginx
# SUCCESS: nginx now on proxy-tier network
```

**4. Verified Resolution:**
```bash
curl -I https://crm.restksolutions.co.zw/login
# HTTP/2 200 OK ✓
```

### Long-term Fix (To Apply)

**1. Update Entrypoint Script** (backend/entrypoint.prod.sh):
```bash
#!/bin/sh
# Removed: set -e
# Removed: collectstatic command (run separately in deployment)

echo "Waiting for database..."
python manage.py migrate --noinput

echo "Starting application..."
exec "$@"
```

**2. Update Deployment Script** (scripts/crm.ps1):
Ensure `collectstatic` runs BEFORE backend starts:
```powershell
# Line ~167 in Deploy function
RunRemote "cd $VPS_DIR && docker compose run --rm --user root backend python manage.py collectstatic --noinput"
```

**3. Fix Docker Compose Network Configuration:**
Ensure nginx is properly configured for both networks in docker-compose.prod.yml (already correct in file, but deployment didn't apply it).

## Prevention

- [x] Fixed volume permissions
- [x] Simplified entrypoint script (local change made, needs rebuild)
- [x] Connected nginx to proxy-tier network
- [ ] Rebuild and push updated backend image with new entrypoint
- [ ] Add health check monitoring/alerts for container crash loops
- [ ] Document volume permission requirements in deployment docs
- [ ] Add automatic network connection verification to deployment script
- [ ] Create migrations for quotations app

## Files Modified

**Local Changes (need Docker rebuild to apply):**
- `backend/entrypoint.prod.sh` - Removed `set -e` and collectstatic

**VPS Changes (applied directly):**
- Fixed `crm_static_files` volume permissions
- Connected nginx to `proxy-tier` network
- Ran collectstatic manually

## Commands for Future Reference

**Check container status:**
```bash
ssh winstontino@159.198.42.231 "cd /home/winstontino/apps/crm && docker compose ps"
```

**View backend logs:**
```bash
ssh winstontino@159.198.42.231 "cd /home/winstontino/apps/crm && docker compose logs --tail=100 backend"
```

**Fix static files permissions:**
```bash
docker run --rm -v crm_static_files:/staticfiles alpine sh -c 'chmod -R 777 /staticfiles'
```

**Connect to proxy-tier network:**
```bash
docker network connect --alias crm-nginx proxy-tier crm-nginx-1
```

**Verify site is up:**
```bash
curl -I https://crm.restksolutions.co.zw/login
```

## Related Issues
- None (first logged issue)

## References
- CRM deployment script: `crm/scripts/crm.ps1`
- Backend Dockerfile: `crm/backend/Dockerfile.prod`
- Docker Compose: `crm/docker-compose.prod.yml`
- Entrypoint script: `crm/backend/entrypoint.prod.sh`

---

**Resolved By:** Claude Code
**Time to Resolution:** ~1.5 hours
**VPS Access:** winstontino@159.198.42.231
**Domain:** https://crm.restksolutions.co.zw
