# Host Caddy Displaced the Docker Reverse Proxy

**Date:** 2026-11-02
**Project:** RESTK
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

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
**Guardrail:** Keep host `caddy.service` disabled and verify `systemctl is-enabled caddy` reports `disabled` while Docker `caddy-proxy` retains restart policy `always` and owns ports 80/443.

These checks establish a single port owner across reboot and catch a conflicting service before it replaces application routing.

## Solution
### Immediate Fix
Stopped host Caddy through its local management API, corrected and validated the Docker Caddyfile, then recreated `caddy-proxy` with the existing image and Compose definition. The VPS operator ran `sudo systemctl disable --now caddy`. Verified host Caddy is disabled and inactive; Docker proxy owns ports 80/443; CRM, Tese, ProjectFlow, Savens, and MLMS respond over HTTPS with valid certificates.

### Long-term Fix
Docker `caddy-proxy` is the declared port owner and retains restart policy `always`. Recheck `systemctl is-enabled caddy`, Docker port bindings, and public routes after the next planned reboot.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Production `docker inspect caddy-proxy` and `/etc/caddy/Caddyfile`, checked 2026-11-02.

---

**Resolved By:** Codex and VPS operator
**Time to Resolution:** Same session
