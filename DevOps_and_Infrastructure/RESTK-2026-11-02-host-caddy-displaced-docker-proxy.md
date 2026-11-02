# Host Caddy Displaced the Docker Reverse Proxy

**Date:** 2026-11-02
**Project:** RESTK
**Environment:** Production
**Severity:** Critical
**Status:** Investigating

## Summary
After the VPS restarted, the enabled host `caddy.service` occupied port 80. The intended `caddy-proxy` container could not bind that port and exited. Public application hostnames are served the host Caddy default page; port 443 has no listener.

## Symptoms
- `caddy-proxy` is `Exited (128)` with `address already in use` for port 80.
- Requests with CRM, Tese, and ProjectFlow Host headers all return the default Caddy page.
- No process listens on port 443.

## Environment Details
- **Server/Host:** `server1.tesemarket.com` (`restk-vps`)
- **Services Affected:** Public routes in `/home/winstontino/core/Caddyfile`
- **Related Components:** Host `caddy.service`, Docker `caddy-proxy`, port 80/443 bindings
- **Time First Observed:** 2026-11-02 08:49 UTC; container exited at 2026-11-01 11:39 UTC

## Investigation Steps
### 1. Initial Diagnosis
Checked `docker ps -a`, `systemctl`, and listening TCP ports.

### 2. Root Cause Analysis
`docker inspect caddy-proxy` reports failure to bind host port 80. The enabled host Caddy service listens on port 80 with the default `/etc/caddy/Caddyfile`.

```bash
docker inspect caddy-proxy
systemctl status caddy
ss -lntp
curl -H 'Host: crm.restksolutions.co.zw' http://127.0.0.1/
```

### 3. Key Findings
- The intended proxy has route definitions for multiple production domains.
- Host Caddy serves only a static default page.
- The application containers remain mostly running behind the failed proxy.

## Root Cause
Two Caddy deployments claim the same host port; the host service won the bind after restart.

## Prevention / Rule
**Guardrail:** Make startup validation fail if both host `caddy.service` and `caddy-proxy` are enabled to bind port 80.

This catches the port ownership conflict before a reboot can replace application routing with a default page.

## Solution
### Immediate Fix
Pending operational decision on which Caddy instance owns ports 80 and 443; no production changes made during this read-only audit.

### Long-term Fix
Declare one proxy owner in deployment configuration and assert public route responses after reboot.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Production `docker inspect caddy-proxy` and `/etc/caddy/Caddyfile`, checked 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending
