# 2026-05-25: Image Upload 404 Fix - Nginx Proxy Configuration

**Date:** May 25, 2026 (22:23 UTC deployment)
**System:** TESE Marketplace - Image Serving
**Severity:** HIGH - All product images failing to load
**Type:** Infrastructure Configuration Bug
**Status:** RESOLVED

---

## Executive Summary

Product images were returning 404 errors on the customer store because the API gateway nginx was trying to serve uploads from a local directory that didn't exist, instead of proxying to the store-api which actually has the files.

**Root Cause:** Nginx `alias` directive pointing to non-existent `/app/uploads/` in API gateway container.

**Fix:** Changed to `proxy_pass` to route `/uploads/*` requests to `store-api:8000` which serves static files.

**Impact:** ALL product images were broken on customer store.

---

## The Bug

### Symptoms

**Browser Console Error:**
```
GET https://tesemarket.com/uploads/51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg 404 (Not Found)
```

**User Experience:**
- Product images show broken image icon
- No product photos visible on listings
- Product detail pages missing images
- Poor shopping experience

**Test from VPS (before fix):**
```bash
curl -I https://tesemarket.com/uploads/51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg
# HTTP/2 404
```

---

## Root Cause Analysis (5 Whys)

### WHY #1: Why are images returning 404?

**Answer:** The nginx API gateway can't find the image files.

**Evidence:**
```bash
curl -I https://tesemarket.com/uploads/51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg
# HTTP/2 404
# server: nginx/1.31.0
```

Nginx is serving the request but file not found.

---

### WHY #2: Why can't nginx find the files?

**Answer:** Nginx is configured to serve from `/app/uploads/` directory which doesn't have the images.

**Evidence:**

**Nginx config** (`/etc/nginx/conf.d/default.conf`):
```nginx
location /uploads/ {
    alias /app/uploads/;  # ← Tries to serve locally
    expires 30d;
    add_header Cache-Control "public, no-transform";
}
```

**Directory check in API gateway:**
```bash
docker exec tese-api-gateway ls -la /app/uploads
# total 12
# drwxr-xr-x 3 1000 1000 4096 Jan 24 07:35 .
# drwxr-xr-x 3 root root 4096 May 25 11:17 ..
# drwxrwxr-x 2 1000 1000 4096 Jan 24 07:35 listings  ← Only this subdirectory
```

The image file doesn't exist here!

---

### WHY #3: Why don't the images exist in API gateway's /app/uploads/?

**Answer:** Images are actually stored in the `tese-store-api` container, not the API gateway.

**Evidence:**

**Store-API has the files:**
```bash
docker exec tese-store-api ls -la /app/uploads
# total 24
# -rw-r--r-- 1 root root 7256 May 25 21:38 51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg ✓
```

**Store-API serves them correctly:**
```bash
docker exec tese-store-api curl -I http://localhost:8000/uploads/51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg
# HTTP/1.1 200 OK ✓
# content-type: image/jpeg
# content-length: 7256
```

---

### WHY #4: Why are images stored in store-api instead of a shared volume?

**Answer:** Store-API handles image uploads and stores them locally. No shared volume configured.

**Evidence:**

**Store-API code** (`apps/store-api/app/main.py`):
```python
# Line 42-46: Sets up uploads directory
BASE_DIR = Path(__file__).resolve().parent.parent
UPLOADS_DIR = BASE_DIR / settings.UPLOAD_DIR  # "uploads"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

# Line 120: Mounts as static files
app.mount("/uploads", StaticFiles(directory=str(UPLOADS_DIR)), name="uploads")

# Line 147-166: Upload endpoint
@app.post("/api/image-upload")
async def upload_image(file: UploadFile = File(...)):
    # ... validation ...
    file_path = UPLOADS_DIR / unique_filename
    # Saves to /app/uploads/ inside store-api container
```

**Container mounts:**
```bash
docker inspect tese-store-api | grep Mounts
# "Mounts": [],  ← No volumes mounted
```

Images saved directly to container filesystem.

---

### WHY #5: Why wasn't this caught earlier?

**Answer:** The old nginx config might have worked with a different deployment setup, or images were tested differently.

**Possible scenarios:**
1. Config was copied from a setup where API gateway had uploads mounted
2. Images were tested via API endpoint (`/api/image-upload` returns URL) but not actually loaded in browser
3. Admin dashboard might use different image paths that work

---

## The Engineering Fix

### Changes Made

**File:** `nginx/gateway.conf`

**BEFORE:**
```nginx
# Uploads/Media
location /uploads/ {
    alias /app/uploads/;  # ← Tries to serve from local dir (wrong!)
    expires 30d;
    add_header Cache-Control "public, no-transform";
}
```

**AFTER:**
```nginx
# Uploads/Media - Proxy to store-api which serves static files
location /uploads/ {
    proxy_pass http://store_api;  # ← Proxies to store-api (correct!)
    expires 30d;
    add_header Cache-Control "public, no-transform";
}
```

**Why This Works:**

1. **Request flow (BEFORE - broken):**
   ```
   User: GET /uploads/image.jpg
   ↓
   Caddy (tesemarket.com)
   ↓
   API Gateway nginx
   ↓
   Tries to serve from /app/uploads/image.jpg (doesn't exist)
   ↓
   404 Not Found ✗
   ```

2. **Request flow (AFTER - fixed):**
   ```
   User: GET /uploads/image.jpg
   ↓
   Caddy (tesemarket.com)
   ↓
   API Gateway nginx
   ↓
   Proxies to store-api:8000/uploads/image.jpg
   ↓
   Store-API StaticFiles serves from /app/uploads/image.jpg
   ↓
   200 OK with image ✓
   ```

---

## Deployment

### 1. Update Config File

```bash
# Edit nginx/gateway.conf
# Change: alias /app/uploads/
# To: proxy_pass http://store_api;
```

### 2. Upload to VPS

```bash
scp nginx/gateway.conf winstontino@159.198.42.231:/home/winstontino/
ssh winstontino@159.198.42.231
cp /home/winstontino/gateway.conf /home/winstontino/apps/tese-marketplace/nginx/gateway.conf
```

### 3. Test & Reload Nginx

```bash
# Test config
docker exec tese-api-gateway nginx -t
# nginx: configuration file /etc/nginx/nginx.conf test is successful ✓

# Reload nginx (zero downtime)
docker exec tese-api-gateway nginx -s reload
# 2026/05/25 22:21:36 [notice] 126#126: signal process started
```

**Deployment Timestamp:** May 25, 2026 22:21 UTC

---

## Verification

### Test 1: Direct Store-API Access

```bash
docker exec tese-store-api curl -I http://localhost:8000/uploads/51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg
```

**Result:**
```
HTTP/1.1 200 OK ✓
content-type: image/jpeg
content-length: 7256
```

### Test 2: Public Domain Access

```bash
curl -I https://tesemarket.com/uploads/51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg
```

**Result:**
```
HTTP/2 200 ✓
content-type: image/jpeg
content-length: 7256
cache-control: max-age=2592000
cache-control: public, no-transform
expires: Wed, 24 Jun 2026 22:23:05 GMT
```

### Test 3: Store-API Logs

```bash
docker logs tese-store-api --tail 5
```

**Result:**
```
INFO: 192.168.48.12:45554 - "HEAD /uploads/51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg HTTP/1.1" 200 OK ✓
```

Request successfully proxied to store-api and served.

### Test 4: API Gateway Logs

```bash
docker logs tese-api-gateway --tail 10 | grep uploads
```

**Result:**
```
172.31.0.2 - - [25/May/2026:22:23:05 +0000] "HEAD /uploads/51682560-3d9d-46f8-be63-d5a8c40d4bbf.jpg HTTP/1.1" 200 0 ✓
```

Nginx successfully proxied the request.

---

## Impact Assessment

### Before Fix

**User Experience:**
- ❌ No product images visible
- ❌ Broken image icons everywhere
- ❌ Can't see what products look like
- ❌ Poor shopping experience
- ❌ Likely reduced conversions

**Affected:**
- Customer store (tesemarket.com)
- All product listings
- Product detail pages
- Search results
- Featured products

### After Fix

**User Experience:**
- ✅ Product images load correctly
- ✅ Normal e-commerce experience
- ✅ Can browse products with photos
- ✅ Professional appearance

**Cache Note:** Browsers may have cached 404 responses, users should hard refresh.

---

## Technical Details

### Store-API StaticFiles Mount

**Code:** `apps/store-api/app/main.py` (line 120)
```python
app.mount("/uploads", StaticFiles(directory=str(UPLOADS_DIR)), name="uploads")
```

**How it works:**
- FastAPI's `StaticFiles` serves files from filesystem
- Mounts at `/uploads` path
- Directory: `/app/uploads/` inside store-api container
- Handles: `GET /uploads/{filename}`

### Nginx Proxy vs Alias

**Alias (broken approach):**
```nginx
location /uploads/ {
    alias /app/uploads/;  # Serve from local filesystem
}
```
- Serves files from nginx container's filesystem
- Fast (no proxy overhead)
- **Problem:** Files don't exist there!

**Proxy (working approach):**
```nginx
location /uploads/ {
    proxy_pass http://store_api;  # Forward to backend
}
```
- Forwards requests to store-api
- Slight overhead (internal network hop)
- **Benefit:** Files actually exist there!

### Performance Consideration

**Proxy overhead:**
- Internal Docker network latency: ~1ms
- Minimal impact for serving images
- Caching headers (30 days) reduce requests

**Better long-term solution:**
- Shared volume for uploads between containers
- Or object storage (S3, Cloudflare R2)
- But proxy works fine for current scale

---

## Alternative Solutions Considered

### Option 1: Shared Volume (Not Chosen)

**Approach:**
```yaml
volumes:
  - tese_uploads:/app/uploads

services:
  api-gateway:
    volumes:
      - tese_uploads:/app/uploads
  store-api:
    volumes:
      - tese_uploads:/app/uploads
```

**Pros:**
- No proxy overhead
- Faster file serving

**Cons:**
- Requires docker-compose changes
- Needs container restart
- More complex deployment

**Verdict:** Proxy solution is simpler and works fine.

### Option 2: Object Storage (Future Enhancement)

**Approach:**
- Upload images to S3/Cloudflare R2
- Serve via CDN
- Store only URLs in database

**Pros:**
- Scalable
- CDN edge caching
- No container storage

**Cons:**
- Costs money
- More complex upload logic
- External dependency

**Verdict:** Good for future, but proxy works now.

### Option 3: Nginx Proxy (Chosen ✓)

**Approach:**
- Proxy `/uploads/` to `store-api:8000`
- Let store-api serve files via StaticFiles

**Pros:**
- ✅ Simple config change
- ✅ Zero downtime reload
- ✅ No code changes needed
- ✅ Works immediately

**Cons:**
- Slight proxy overhead (negligible)

**Verdict:** Best solution for immediate fix.

---

## Prevention Measures

### 1. Document Upload Architecture

**Create:** `docs/UPLOADS.md`
```markdown
# Upload Architecture

## Where Uploads Are Stored

Images are stored in the `store-api` container at `/app/uploads/`.

## How Uploads Are Served

1. User uploads via: `POST /api/image-upload` (store-api)
2. File saved to: `/app/uploads/{uuid}.{ext}`
3. Response: `{"url": "/uploads/{uuid}.{ext}"}`
4. Frontend uses: `<img src="/uploads/{uuid}.{ext}">`
5. Request flow:
   - Caddy → API Gateway → Store-API
   - Store-API serves via StaticFiles mount

## Nginx Configuration

API gateway must proxy `/uploads/` to `store-api:8000`:

```nginx
location /uploads/ {
    proxy_pass http://store_api;
}
```

DO NOT use `alias` - files don't exist in gateway!
```

### 2. Add Smoke Test

**Test:** Check image serving after deployment
```bash
# In smoke tests
curl -I https://tesemarket.com/uploads/test-image.jpg
# Should return 200 or 404, NOT 502/503
```

### 3. Monitor Upload Endpoint

**Metrics to track:**
- Upload success rate
- Image serve 404 rate
- Store-API `/uploads/*` requests

### 4. Consider Shared Volume for Production

**Future enhancement:**
- Move to shared volume or object storage
- Better scalability
- Easier horizontal scaling

---

## Related Files

**Modified:**
```
nginx/gateway.conf  (Line 99-103: Changed alias to proxy_pass)
```

**Related Code:**
```
apps/store-api/app/main.py        (Upload handling & static files)
apps/store-api/app/config.py      (UPLOAD_DIR configuration)
```

**Infrastructure:**
```
VPS: /home/winstontino/apps/tese-marketplace/nginx/gateway.conf
Container: tese-api-gateway:/etc/nginx/conf.d/default.conf
```

---

## Sign-off

**Issue Resolution:** Complete
**Type:** Infrastructure Configuration Bug
**Testing:** Manual verification with curl and browser
**Deployment:** May 25, 2026 22:21 UTC (nginx reload)
**Downtime:** 0 seconds (nginx reload is zero-downtime)

**Engineer:** Claude (assisted by User)
**Time to Resolution:** ~15 minutes (investigation + fix + deployment)
**Severity:** HIGH (P1) - All images broken
**User Impact:** ALL customer store users affected

**Root Cause Category:** Infrastructure Misconfiguration

---

**Status:** ✅ RESOLVED

**Key Takeaway:** Always verify file locations match configuration. `alias` serves from local filesystem, `proxy_pass` forwards to backend. In microservices, files stored in one container need proxy routing from gateway, not local file serving.
