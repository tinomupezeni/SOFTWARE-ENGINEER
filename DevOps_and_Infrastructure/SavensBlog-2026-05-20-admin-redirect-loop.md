# ISSUE LOG: Admin Dashboard Redirect Loop (ERR_TOO_MANY_REDIRECTS)
**Date:** 2026-05-20
**Project:** Savens Blog
**Status:** RESOLVED (Architectural Proxy Alignment - Solution 2 Implemented)

## 1. Symptoms
- Accessing `https://blogadmin.hbca.tech/login/` resulted in `net::ERR_TOO_MANY_REDIRECTS`.
- The browser was caught in an infinite loop of 301/308 redirects back to the same URL.

## 2. Root Cause Analysis
The issue was a **Protocol Header Mismatch** in the multi-tier reverse proxy architecture:
1. **Caddy (Layer 1)**: Received the HTTPS request and proxied it as HTTP to the Admin Nginx container.
2. **Admin Nginx (Layer 2)**: Was configured with `proxy_set_header X-Forwarded-Proto $scheme;`. Since the internal connection was HTTP, it sent `X-Forwarded-Proto: http` to the backend.
3. **Django Backend (Layer 3)**: Has `SECURE_SSL_REDIRECT = True`. It saw the `http` header and issued a redirect to `https`.
4. **The Loop**: Nginx received the backend's redirect and passed it back to Caddy, which passed it to the browser.

## 3. Resolution Strategy

### Solution 2: Protocol Pass-through (Implemented)
- **Action**: Updated Admin Nginx configuration to use `proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;`.
- **Rationale**: This preserves the original protocol header sent by the edge proxy (Caddy). By passing through the header, we ensure the backend receives a consistent "https" signal throughout the entire proxy chain. This is the **Principal-level best practice** for multi-hop architectures.

## 4. Verification Results
- `https://blogadmin.hbca.tech/login/` -> **200 OK** (correctly reaching backend).
- `https://blogadmin.hbca.tech/login` -> **200 OK** (correctly serving SPA).
- Verified header propagation using `curl -v`.

## 5. Lessons Learned
- **Preserve Edge State**: In nested proxies, never trust `$scheme` if the upstream is SSL-terminated. Always propagate the original protocol from the edge to prevent framework-level security redirects from triggering loops.
