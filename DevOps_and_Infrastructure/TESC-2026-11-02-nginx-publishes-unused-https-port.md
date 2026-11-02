# Nginx Publishes an Unused HTTPS Port

**Date:** 2026-11-02
**Project:** TESC
**Environment:** Production
**Severity:** Low
**Status:** Investigating

## Summary
The production Docker Compose file publishes host port 443 to the Nginx container, but the live Nginx configuration only listens on port 80. Local HTTPS to the VM resets the connection, while the public HTTPS hostname resolves to a separate edge address and succeeds.

## Symptoms
- `docker ps` advertises `0.0.0.0:443->443/tcp` for `tesc-main-nginx-1`.
- `nginx -T` has no `listen 443` server.
- `curl https://127.0.0.1/` on the VM fails during TLS handshake.

## Environment Details
- **Server/Host:** `tesc-prod` (`10.50.200.35`)
- **Services Affected:** Direct HTTPS to the VM and deployment documentation
- **Related Components:** `docker-compose.yml`, `nginx/nginx.conf`, upstream TLS edge
- **Time First Observed:** 2026-11-02 09:42 UTC

## Investigation Steps
### 1. Initial Diagnosis
Compared Docker published ports with `nginx -T`.

### 2. Root Cause Analysis
Confirmed the config has only port 80 listeners and direct local TLS fails. Public HTTPS resolves to `102.217.49.126`, a different address than the VM.

```bash
docker exec tesc-main-nginx-1 nginx -T
docker inspect tesc-main-nginx-1
curl -kI https://127.0.0.1/
getent ahostsv4 tesc.zchpc.ac.zw
```

### 3. Key Findings
- Nginx routes application traffic over HTTP inside the VM.
- Public HTTPS works, so TLS likely terminates upstream; the exact edge component was not visible from this VM.
- The port 443 mapping suggests TLS exists locally when it does not.

## Root Cause
The Compose port publication and Nginx listener configuration describe different HTTPS responsibilities.

## Prevention / Rule
**Guardrail:** Require each published Nginx port to have a tested listener and document the exact TLS termination point.

This keeps direct VM behavior and operator expectations aligned with the deployed network path.

## Solution
### Immediate Fix
No production networking changed during this read-only inspection.

### Long-term Fix
Confirm the edge TLS design, then remove the unused 443 mapping or configure and test a local TLS listener if direct VM HTTPS is required.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Live Compose, Nginx, Docker, DNS, and curl observations, 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending
