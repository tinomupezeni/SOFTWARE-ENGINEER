# Production Deployment, Networking, and Database Deadlock Issues

**Date:** 2026-06-30
**Project:** TESC
**Environment:** Production (ZCHPC VM & cPanel)
**Severity:** Critical
**Status:** Resolved

## Summary
The initial production deployment of the TESC platform to the ZCHPC VM infrastructure encountered a cascading series of networking, firewall, Docker, and database issues. These ranged from hardcoded local API paths in the React apps, to AppArmor-induced Docker permission deadlocks, strict institutional hardware firewalls dropping cPanel traffic, internal Docker routing failures causing backend worker timeouts, and Docker cache ignoring migration files during builds.

## Symptoms
- React frontends fetching data from `localhost:8000` instead of the production API.
- `docker compose down` and `docker rm` failing with `permission denied` errors due to Ubuntu AppArmor locking Snap Docker processes.
- cPanel reverse proxy throwing `504 Gateway Time-out` when attempting to route traffic to the VM's Docker containers on port `8080` or `8085`.
- SSH terminal reporting `No route to host` or `Network is unreachable` when trying to access the VM.
- Django backend Gunicorn workers throwing `[CRITICAL] WORKER TIMEOUT` and `SIGKILL` 50 seconds after booting, causing `curl -I http://localhost:8000/api/` to hang indefinitely.
- `ValueError: Dependency on app with no migrations: users` when running migrations on the VM.

## Environment Details
- **Server/Host:** ZCHPC VM (Private IP: `10.50.200.35`) & External cPanel Proxy
- **Services Affected:** `frontend_client`, `frontend_admin`, `backend`, `db`, and Docker's internal Nginx proxy.
- **Related Components:** Docker Snap, UFW, IPTables, Gunicorn, Django, React.

## Investigation Steps

### 1. Hardcoded API Paths
Initially, the React frontends were built using `http://localhost:8000` for the API URL, causing the deployed site to attempt to query the user's local machine instead of the production server.

### 2. Docker AppArmor Permission Deadlocks
When attempting to restart containers to fix port mappings, Docker threw `permission denied` errors on `containerd-shim-runc-v2`. We diagnosed this as a known AppArmor bug affecting Snap installations of Docker.

### 3. The cPanel 504 Gateway Time-out (ZCHPC Firewall)
After pointing cPanel's `proxy_pass` to the VM, it repeatedly timed out. We discovered that the VM (`10.50.200.35`) was behind the ZCHPC institutional hardware firewall. Even though UFW was disabled on the VM, the network hardware dropped all web traffic (ports 8080, 8085) traversing the network from the cPanel server to the VM.

### 4. Backend Worker Timeout & Internal Docker Routing
When curl-ing the backend from inside the VM, it hung indefinitely. Checking the logs revealed Gunicorn workers timing out and being killed. We ran a manual migration which exposed the root cause:
```python
django.db.utils.OperationalError: connection to server at "db" (172.20.0.2), port 5432 failed: Connection timed out
```
The hard restarts of Docker broke its internal iptables integration, causing the host to DROP traffic traversing the Docker bridge network (`main_net`).

### 5. Missing Migrations in Docker Cache
After fixing the database connection, the migrations threw a Django error indicating the `users` app had no migrations. We discovered that when building the image on the VM (`docker compose up --build`), Docker aggressively cached the `COPY . .` step and didn't pull the fresh `migrations` folder.

## Root Cause
1. Hardcoded environment variables in React frontend code.
2. Snap Docker + AppArmor conflict causing locked file descriptors on container stop.
3. Institutional network firewall (ZCHPC) blocking arbitrary high ports (8080, 8085) between the cPanel server and the VM.
4. Docker's internal `FORWARD` iptables rules being wiped during forced daemon restarts, isolating containers.
5. Docker's build cache preserving stale code during rebuilds.

## Solution

### Immediate Fix

**1. Dynamic API Paths:**
We refactored the Axios configs in React to use relative paths (`/api`) so the browser resolves the domain dynamically.

**2. Hard Restart Script:**
Created `~/docker_hard_restart.sh` to bypass AppArmor bugs:
```bash
sudo systemctl stop docker
sudo systemctl stop containerd
sudo killall -9 containerd-shim-runc-v2 2>/dev/null
sudo systemctl restart apparmor
sudo systemctl start containerd
sudo systemctl start docker
sudo docker rm -f $(sudo docker ps -aq)
sudo docker compose -f docker-compose.prod.yml up -d
```

**3. Bypassing Internal Nginx & Port Mapping:**
Removed the Docker-based Nginx container entirely to reduce complexity. Mapped the container ports directly to the VM host:
- `frontend_client`: `8080:80`
- `frontend_admin`: `8081:80`
- `backend`: `8000:8000`
Configured the cPanel Nginx to proxy directly to these individual ports on `10.50.200.35`.

**4. Fixing Internal Docker Routing:**
Forced iptables to allow traffic across the Docker bridge:
```bash
sudo iptables -P FORWARD ACCEPT
```

**5. Bypassing Docker Cache for Migrations:**
Instead of fighting the cache, we generated the migrations directly inside the running container and applied them:
```bash
sudo docker exec -it tesc-main-backend-1 python manage.py makemigrations users
sudo docker exec -it tesc-main-backend-1 python manage.py makemigrations
sudo docker exec -it tesc-main-backend-1 python manage.py migrate
```

### Long-term Fix
- Ensure all API calls in frontends use relative `/api` paths.
- If the VM's Docker snap keeps locking, consider migrating to the native `apt` docker installation.
- Add `--no-cache` to docker compose build commands when critical structural changes (like migrations) are introduced.

## Prevention
- [x] Configuration changes needed (Nginx removed, cPanel proxy updated)
- [ ] Code changes required (Relative Axios URLs merged)

---

**Resolved By:** Antigravity (AI)
**Time to Resolution:** ~2.5 hours
