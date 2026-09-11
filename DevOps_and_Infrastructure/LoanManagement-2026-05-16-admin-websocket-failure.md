# WebSocket Connection Failure on Admin System

**Date:** 2026-05-16
**Project:** LoanManagement
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The Admin Portal (probitasadmin.restksolutions.co.zw) is experiencing WebSocket connection failures when attempting to connect to the notifications service (/ws/notifications/). This prevents real-time notifications from being displayed in the dashboard.

## Symptoms
- Browser console logs: WebSocket connection failed.
- Notifications WebSocket error: Event {isTrusted: true, type: error, ...}
- Notifications are never received; the system keeps attempting to reconnect every 5 seconds.

## Environment Details
- **Server/Host:** VPS (Ubuntu/Docker)
- **Services Affected:** mlms-admin-api (Backend), mlms-admin-frontend (UI)
- **Related Components:** Caddy (Reverse Proxy), Daphne (ASGI Server), Django Channels
- **Time First Observed:** 2026-05-16

## Investigation Steps

### 1. Initial Diagnosis
Checked the backend configuration in admin/backend/config/asgi.py and apps/notifications/routing.py. Verified that the backend is running daphne (ASGI server) which supports WebSockets.

### 2. Root Cause Analysis
Analyzed the reverse proxy configuration (Caddyfile.master and nginx/nginx.vps.ssl.conf).

**Findings in Caddyfile:**
The probitasadmin.restksolutions.co.zw block has specific handles for /api/*, /admin/*, and /static/*, but is missing a handle for /ws/*.
```caddy
probitasadmin.restksolutions.co.zw {
    import security
    handle /api/* { reverse_proxy mlms-admin-api:8000 }
    handle /admin/* { reverse_proxy mlms-admin-api:8000 }
    handle /static/* { reverse_proxy mlms-admin-api:8000 }
    handle {
        reverse_proxy mlms-admin-frontend:80
    }
}
```

### 3. Key Findings
- **Missing Proxy Route:** The reverse proxy does not have a routing rule for paths starting with /ws/.
- **Misrouting:** Because /ws/notifications/ doesn't match the specific API handles, it hits the catch-all handle and is sent to the Frontend container (mlms-admin-frontend:80).
- **Handshake Failure:** The frontend service (likely Nginx serving static files) receives the WebSocket upgrade request and returns a standard HTTP response (likely the React apps index.html), which the browser rejects as a valid WebSocket upgrade.

## Root Cause
The reverse proxy (Caddy) is missing a dedicated handle for the WebSocket path (/ws/*), causing these requests to be incorrectly routed to the frontend service instead of the Daphne ASGI backend.

## Solution

### Immediate Fix
Add a handle for /ws/* to the probitasadmin.restksolutions.co.zw block in the Caddyfile:
```caddy
    handle /ws/* {
        reverse_proxy mlms-admin-api:8000
    }
```

### Long-term Fix
Standardize the reverse proxy templates to always include WebSocket handles for any backend service that implements Django Channels.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- PRODUCTION_SYNC_ISSUES.md (Previous issue with Daphne/Gunicorn mismatch)

## References
- Caddy Documentation on Reverse Proxying WebSockets

---

**Resolved By:** Gemini CLI
**Time to Resolution:** Investigated in < 15 minutes
