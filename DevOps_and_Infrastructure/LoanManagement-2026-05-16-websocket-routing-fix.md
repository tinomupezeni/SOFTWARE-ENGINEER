# WebSocket Routing Resolution - Admin & Agent Portals

**Date:** 2026-05-16
**Project:** LoanManagement
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The Admin and Agent Portals were experiencing WebSocket connection failures (/ws/notifications/) because the reverse proxy (Caddy) was incorrectly routing these requests to the frontend containers instead of the Daphne ASGI backend.

## Symptoms
- Admin Portal: WebSocket connection to wss://probitasadmin.restksolutions.co.zw/ws/notifications/ failed.
- Agent Portal: WebSocket connection to wss://probitasadmin.restksolutions.co.zw/ws/notifications/ failed (noted during investigation that both frontends connect to the Admin API for notifications).
- Browser console: Notifications WebSocket error: Event {isTrusted: true, type: error, ...}.

## Root Cause
The Caddy configuration for both probitasadmin.restksolutions.co.zw and probitas.restksolutions.co.zw was missing a specific handle for the /ws/* path. Since /ws/* did not match the defined /api/* or /admin/* handles, it hit the catch-all handle which routes to the frontend Nginx containers. The frontend returned a standard HTTP response (index.html), which caused the WebSocket handshake to fail.

## Prevention / Rule
**Guardrail:** Generate every domain's reverse-proxy block for an
ASGI-backed service from one shared template/snippet that always includes
the `/ws/*` handle, instead of hand-writing each domain's config
independently — a missing handle on one domain and its sibling domain is
the same bug appearing twice because nothing forced them to stay in sync.

This is the second domain to hit the identical missing-handle bug in the
same investigation — a shared template is what stops a fix applied to one
domain from needing to be separately rediscovered on the next.

## Solution

### Immediate Fix
Updated Caddyfile.master to include the missing /ws/* handles for both domains. Both handles route to mlms-admin-api:8000, as the Admin service is the central notification authority.

```caddy
# probitasadmin.restksolutions.co.zw
handle /ws/* {
    reverse_proxy mlms-admin-api:8000
}

# probitas.restksolutions.co.zw
handle /ws/* {
    reverse_proxy mlms-admin-api:8000
}
```

## Prevention
- Standardized reverse proxy configuration to include WebSocket handles for any domain requiring real-time features.
- Deployment checklist updated to verify WebSocket handshake (HTTP 101) after deployment.

---

**Resolved By:** Gemini CLI
**Time to Resolution:** < 30 minutes
