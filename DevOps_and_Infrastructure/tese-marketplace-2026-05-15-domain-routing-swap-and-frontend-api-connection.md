# Domain Routing Swap and Frontend API Connection Issues

**Date:** 2026-05-15
**Project:** Tese Marketplace
**Environment:** Production (VPS)
**Severity:** Critical
**Status:** Resolved

## Summary
Two critical production issues were discovered:
1. Domain routing was swapped - `tesemarket.com` served the admin dashboard while `admin.tesemarket.com` served the customer store
2. Frontend applications were trying to connect to `localhost:8000` instead of production API endpoints, causing `ERR_CONNECTION_REFUSED` errors

## Symptoms
- `tesemarket.com` displayed "Tese Market | Admin" (admin dashboard)
- `admin.tesemarket.com` displayed "TESE - MARKET" (customer store)
- Browser console errors: `Failed to load resource: net::ERR_CONNECTION_REFUSED` for `localhost:8000/api/auth/login`
- Frontend applications unable to authenticate or fetch data

## Environment Details
- **Server/Host:** 159.198.42.231 (VPS)
- **Services Affected:**
  - tese-customer-store (customer-facing frontend)
  - tese-admin-dashboard (admin frontend)
  - tese-api-gateway (nginx reverse proxy)
- **Related Components:**
  - Caddy (external reverse proxy)
  - Nginx (internal routing gateway)
  - Docker containers
  - Vite build system
- **Time First Observed:** 2026-05-15 ~14:30 UTC
- **Downtime:** Partial (sites accessible but non-functional)

## Investigation Steps

### 1. Domain Routing Issue

**Initial Diagnosis:**
```bash
ssh winstontino@159.198.42.231 "curl -s https://tesemarket.com | grep '<title>' && curl -s https://admin.tesemarket.com | grep '<title>'"
```

**Findings:**
```html
tesemarket.com:        <title>Tese Market | Admin</title>     # WRONG
admin.tesemarket.com:  <title>TESE - MARKET</title>           # WRONG
```

**Container Content Verification:**
```bash
docker exec tese-customer-store cat /usr/share/nginx/html/index.html | grep '<title>'
# Result: <title>TESE - MARKET</title> ✓ Correct

docker exec tese-admin-dashboard cat /usr/share/nginx/html/index.html | grep '<title>'
# Result: <title>Tese Market | Admin</title> ✓ Correct
```

**Upstream Testing:**
```bash
docker exec tese-api-gateway curl -s customer-store:80 | grep '<title>'
# Result: <title>TESE - MARKET</title> ✓ Correct

docker exec tese-api-gateway curl -s admin-dashboard:80 | grep '<title>'
# Result: <title>Tese Market | Admin</title> ✓ Correct
```

**Routing Test with Host Headers:**
```bash
docker exec tese-api-gateway curl -H 'Host: tesemarket.com' localhost | grep '<title>'
# Result: <title>Tese Market | Admin</title> ✗ WRONG

docker exec tese-api-gateway curl -H 'Host: admin.tesemarket.com' localhost | grep '<title>'
# Result: <title>TESE - MARKET</title> ✗ WRONG
```

**Root Cause Identified:**
- Nginx configuration file was correct
- Containers had correct content
- Upstream connections worked correctly
- **Nginx hadn't properly loaded the configuration** - was using stale routing rules

### 2. Frontend API Connection Issue

**Browser Console Errors:**
```
Failed to load resource: net::ERR_CONNECTION_REFUSED
localhost:8000/api/auth/login:1
```

**Environment Variable Check:**
```bash
docker exec tese-customer-store env | grep VITE
# Result: VITE_API_URL=https://tesemarket.com/api

docker exec tese-admin-dashboard env | grep VITE
# Result: VITE_API_URL=https://admin.tesemarket.com/api
```

**Built Files Check:**
```bash
docker exec tese-customer-store grep -ao 'localhost:8000' /usr/share/nginx/html/assets/*.js
# Result: 0 matches (but frontend still trying to connect to localhost)
```

**Container Build Date:**
```bash
docker exec tese-customer-store ls -la /usr/share/nginx/html/assets/
# Result: Files dated Apr 20 13:49 (3+ weeks old)
```

**Root Cause Identified:**
- Vite embeds environment variables at **build time**, not runtime
- Docker runtime environment variables in `docker-compose.vps.yml` don't affect Vite builds
- Images were built using development `.env` file with `VITE_API_URL=http://localhost:8000/api`
- Dockerfiles didn't accept build arguments for environment variables

## Root Cause

### Issue 1: Domain Routing Swap
The nginx gateway container's configuration was correct on disk but not loaded in memory. The server was using stale routing rules, possibly from a previous deployment or configuration change that wasn't properly reloaded.

### Issue 2: Frontend API Connection
**Fundamental Vite Environment Variable Misunderstanding:**
- Vite requires environment variables at **build time** (during `vite build`)
- Docker runtime environment variables only exist at **container runtime**
- The build process happens in the Docker image build stage, long before containers start
- The Dockerfiles didn't pass build arguments to Vite, so it used the `.env` file values (localhost)

**Additional Issue:**
- Registry prefix mismatch: built images with `tinomupezeni/*` prefix but `docker-compose.vps.yml` referenced `tinotenda762/*` images

## Solution

### Fix 1: Domain Routing Swap

**Reloaded Nginx Configuration:**
```bash
ssh winstontino@159.198.42.231 "docker exec tese-api-gateway nginx -t"
# nginx: configuration file /etc/nginx/nginx.conf test is successful

ssh winstontino@159.198.42.231 "docker exec tese-api-gateway nginx -s reload"
# 2026/05/15 14:54:37 [notice] 77#77: signal process started
```

**Verification:**
```bash
ssh winstontino@159.198.42.231 "docker exec tese-api-gateway curl -H 'Host: tesemarket.com' localhost | grep '<title>'"
# Result: <title>TESE - MARKET</title> ✓ CORRECT

ssh winstontino@159.198.42.231 "docker exec tese-api-gateway curl -H 'Host: admin.tesemarket.com' localhost | grep '<title>'"
# Result: <title>Tese Market | Admin</title> ✓ CORRECT
```

### Fix 2: Frontend API Connection

**Step 1: Updated Dockerfiles to Accept Build Arguments**

Modified `apps/customer-store/Dockerfile`:
```dockerfile
# Accept build arguments for environment variables
ARG VITE_API_URL=http://localhost:8000/api
ARG VITE_WS_URL=localhost:8000
ARG VITE_STRIPE_PUBLISHABLE_KEY
ARG VITE_GOOGLE_CLIENT_ID

# Set them as environment variables for the build
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_WS_URL=$VITE_WS_URL
ENV VITE_STRIPE_PUBLISHABLE_KEY=$VITE_STRIPE_PUBLISHABLE_KEY
ENV VITE_GOOGLE_CLIENT_ID=$VITE_GOOGLE_CLIENT_ID

# Build the application (Vite now sees production URLs)
RUN pnpm --filter @tese/customer-store build
```

Modified `apps/admin-dashboard/Dockerfile` with same pattern.

**Step 2: Updated Deployment Script**

Modified `local-deploy.ps1` to pass build arguments:
```powershell
# Customer Store
if ($APP -eq "customer-store") {
    docker build -t "$FULL_IMAGE" -f "$DOCKERFILE" `
        --build-arg VITE_API_URL=https://tesemarket.com/api `
        --build-arg VITE_WS_URL=tesemarket.com `
        --build-arg VITE_STRIPE_PUBLISHABLE_KEY=pk_test_... `
        --build-arg VITE_GOOGLE_CLIENT_ID=884184688170-... `
        .
}

# Admin Dashboard
elseif ($APP -eq "admin-dashboard") {
    docker build -t "$FULL_IMAGE" -f "$DOCKERFILE" `
        --build-arg VITE_API_URL=https://admin.tesemarket.com/api `
        --build-arg VITE_WS_URL=admin.tesemarket.com `
        --build-arg VITE_STRIPE_PUBLISHABLE_KEY=pk_test_... `
        --build-arg VITE_GOOGLE_CLIENT_ID=884184688170-... `
        .
}
```

Also fixed registry prefix: `$REGISTRY_PREFIX = "tinotenda762"`

**Step 3: Rebuild and Deploy**

```bash
# Build customer store with production API URL
docker build -t tinotenda762/tese-customer-store:latest \
  -f apps/customer-store/Dockerfile \
  --build-arg VITE_API_URL=https://tesemarket.com/api \
  --build-arg VITE_WS_URL=tesemarket.com \
  --build-arg VITE_STRIPE_PUBLISHABLE_KEY=pk_test_... \
  --build-arg VITE_GOOGLE_CLIENT_ID=884184688170-... \
  .

# Build admin dashboard with production API URL
docker build -t tinotenda762/tese-admin-dashboard:latest \
  -f apps/admin-dashboard/Dockerfile \
  --build-arg VITE_API_URL=https://admin.tesemarket.com/api \
  --build-arg VITE_WS_URL=admin.tesemarket.com \
  --build-arg VITE_STRIPE_PUBLISHABLE_KEY=pk_test_... \
  --build-arg VITE_GOOGLE_CLIENT_ID=884184688170-... \
  .

# Transfer to VPS
docker save tinotenda762/tese-customer-store:latest | ssh winstontino@159.198.42.231 "docker load"
docker save tinotenda762/tese-admin-dashboard:latest | ssh winstontino@159.198.42.231 "docker load"

# Recreate containers
ssh winstontino@159.198.42.231 "cd /home/winstontino/apps/tese-marketplace && docker compose -f docker-compose.vps.yml up -d --force-recreate --no-deps customer-store admin-dashboard"
```

**Verification:**
```bash
# Check API URLs are embedded in JavaScript bundles
ssh winstontino@159.198.42.231 "docker exec tese-customer-store sh -c 'cat /usr/share/nginx/html/assets/index-*.js' | grep -o 'https://tesemarket.com/api' | head -1"
# Result: https://tesemarket.com/api ✓

ssh winstontino@159.198.42.231 "docker exec tese-admin-dashboard sh -c 'cat /usr/share/nginx/html/assets/index-*.js' | grep -o 'https://admin.tesemarket.com/api' | head -1"
# Result: https://admin.tesemarket.com/api ✓

# Check domains are working
curl -s https://tesemarket.com | grep '<title>'
# Result: <title>TESE - MARKET</title> ✓

curl -s https://admin.tesemarket.com | grep '<title>'
# Result: <title>Tese Market | Admin</title> ✓
```

## Prevention

**For Domain Routing Issues:**
- [ ] Add automated verification to deployment script that tests routing after deployment
- [ ] Include `nginx -s reload` in deployment workflow after configuration updates
- [ ] Monitor nginx configuration reload success in logs
- [ ] Consider adding health checks that verify correct routing

**For Vite Environment Variables:**
- [x] Updated all frontend Dockerfiles to accept build arguments
- [x] Updated deployment script to pass production values during build
- [x] Fixed registry prefix mismatch in deployment script
- [ ] Document Vite's build-time vs runtime environment variable behavior
- [ ] Create separate `.env.production` files for clarity
- [ ] Add CI/CD checks to verify correct API URLs in built bundles
- [ ] Consider using runtime environment variable injection for non-bundled configs

## Files Modified

**Configuration Files:**
- `apps/customer-store/Dockerfile` - Added ARG and ENV for build-time variables
- `apps/admin-dashboard/Dockerfile` - Added ARG and ENV for build-time variables
- `local-deploy.ps1` - Added build arguments for frontend apps, fixed registry prefix

**No Changes Required:**
- `docker-compose.vps.yml` - Runtime env vars kept (not used by Vite but good for documentation)
- `nginx/nginx.conf` - Already correct
- `.env` files - Kept for local development

## Key Learnings

### 1. Vite Environment Variables
Vite environment variables work differently from traditional runtime configs:
- `VITE_*` variables must be available during `vite build`
- Vite statically replaces `import.meta.env.VITE_*` with actual values
- Docker runtime environment variables come too late in the process
- Solution: Use Docker build arguments (ARG) to set build-time environment variables

### 2. Docker Image Tags Matter
Registry prefix mismatch caused confusion:
- Built: `tinomupezeni/tese-*:latest`
- Expected: `tinotenda762/tese-*:latest`
- Docker pulled correct tags but old images remained
- Always verify image tags match between build and deployment

### 3. Nginx Configuration Reloads
- Configuration files can be correct but not loaded
- Always verify with `nginx -t` and reload with `nginx -s reload`
- Container restarts don't guarantee configuration reload if files unchanged

## Commands for Future Reference

**Reload Nginx in container:**
```bash
ssh winstontino@159.198.42.231 "docker exec tese-api-gateway nginx -s reload"
```

**Verify API URLs in built frontend:**
```bash
ssh winstontino@159.198.42.231 "docker exec tese-customer-store sh -c 'cat /usr/share/nginx/html/assets/index-*.js' | grep -o 'https://tesemarket.com/api' | head -1"
```

**Check domain routing:**
```bash
ssh winstontino@159.198.42.231 "curl -s https://tesemarket.com | grep '<title>' && curl -s https://admin.tesemarket.com | grep '<title>'"
```

**Test nginx routing with Host headers:**
```bash
docker exec tese-api-gateway curl -H 'Host: tesemarket.com' localhost | grep '<title>'
docker exec tese-api-gateway curl -H 'Host: admin.tesemarket.com' localhost | grep '<title>'
```

**Build frontend with production API URLs:**
```bash
docker build -t tinotenda762/tese-customer-store:latest \
  -f apps/customer-store/Dockerfile \
  --build-arg VITE_API_URL=https://tesemarket.com/api \
  --build-arg VITE_WS_URL=tesemarket.com \
  .
```

**Deploy using local script:**
```powershell
.\local-deploy.ps1
```

## Related Issues
- None (first deployment issues logged for Tese Marketplace)

## References
- Deployment script: `local-deploy.ps1`
- Customer store Dockerfile: `apps/customer-store/Dockerfile`
- Admin dashboard Dockerfile: `apps/admin-dashboard/Dockerfile`
- Docker Compose: `docker-compose.vps.yml`
- Nginx config: `nginx/nginx.conf`
- Vite docs: https://vitejs.dev/guide/env-and-mode.html

---

**Resolved By:** Claude Code
**Time to Resolution:** ~2 hours
**VPS Access:** winstontino@159.198.42.231
**Domains:**
- https://tesemarket.com (customer store)
- https://admin.tesemarket.com (admin dashboard)
