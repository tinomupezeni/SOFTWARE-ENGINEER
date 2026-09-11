# Redirect Loop Outage - Savens Blog

**Date:** 2026-05-25
**Project:** Savens Blog
**Environment:** Production (VPS: 159.198.42.231)
**Severity:** Critical
**Status:** Resolved (Engineering Fix)

## Summary
A critical production issue was reported where image uploads failed with 
et::ERR_TOO_MANY_REDIRECTS. This prevented authors from publishing content and triggered Service Worker (Workbox) precaching errors in the browser.

## Symptoms
- Image upload requests to /upload/image/ failed with ERR_TOO_MANY_REDIRECTS.
- Axios returned a Network Error without a status code.
- Frontend console showed 
on-precached-url: index.html errors from the Service Worker.
- Backend logs showed WARNING Bad Request: /blog/posts/ and inconsistent protocol detection.

## Root Cause: Protocol Mismatch in Multi-Tier Proxy
The system uses a **Caddy -> Nginx -> Django** architecture.
1. **Caddy** terminates SSL (HTTPS) and forwards requests to the frontend **Nginx** over HTTP.
2. **Nginx** was explicitly setting proxy_set_header X-Forwarded-Proto $scheme;.
3. Since Nginx was receiving HTTP from Caddy, $scheme was always http.
4. **Django** (with SECURE_SSL_REDIRECT = True) saw X-Forwarded-Proto: http and issued a 301 Redirect to https.
5. This created an infinite loop as the redirect was again processed by Nginx and downgraded to http internally.

## Resolution
Implemented **Protocol Transparency** in the Nginx configuration. Instead of hardcoding the local scheme, Nginx now preserves the protocol from the outer proxy (Caddy) while maintaining a fallback for direct access.

### Applied Configuration (Nginx):
`
ginx
# Map block to determine the true protocol
map $http_x_forwarded_proto $proxy_x_forwarded_proto {
    default $http_x_forwarded_proto;
    ''      $scheme;
}

server {
    # ...
    location /api/ {
        # ...
        proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
    }
}
`

### Impact
- Resolved the redirect loop for all authenticated and upload endpoints.
- Standardized proxy behavior across savens-frontend and savens-admin.
- Restored PWA functionality by allowing the Service Worker to correctly handle network requests.

## Prevention
- **Architectural Standard:** All internal proxies in the Savens monorepo MUST use the map based $proxy_x_forwarded_proto pattern.
- **Verification:** Added SECURE_PROXY_SSL_HEADER verification to the deployment checklist.

**Resolved By:** Gemini CLI (Agent)
**Reference:** [LOG_IMAGE_ISSUE.md](./LOG_IMAGE_ISSUE.md) (Related previous incident)
