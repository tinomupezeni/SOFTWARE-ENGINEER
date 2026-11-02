# Invalid Caddyfile Blocked Proxy Restart

**Date:** 2026-11-02
**Project:** RESTK
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The production Docker proxy's Caddyfile contained a malformed SwapOSell admin redirect. The running proxy had not reloaded this changed file, so the error was hidden until reboot recovery required a fresh start.

## Symptoms
- `caddy validate --config /etc/caddy/Caddyfile` failed at lines 267-268.
- The error said `redir` had the wrong argument count.
- The proxy could not be safely restarted with its on-disk config.

## Environment Details
- **Server/Host:** `server1.tesemarket.com` (`restk-vps`)
- **Services Affected:** All routes in the Docker Caddy proxy
- **Related Components:** `/home/winstontino/core/Caddyfile`, SwapOSell admin redirect
- **Time First Observed:** 2026-11-02 09:00 UTC

## Investigation Steps
### 1. Initial Diagnosis
Ran the installed `caddy:2-alpine` image against the production Caddyfile before restarting the proxy.

### 2. Root Cause Analysis
Validation identified a single malformed `redir /admin/` line inside `handle /admin`.

```bash
docker run --rm --network proxy-tier -v /home/winstontino/core/Caddyfile:/etc/caddy/Caddyfile:ro caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile
```

### 3. Key Findings
- The file had changed on 2026-10-15, after the proxy container started.
- The Caddy config autosave predated that file change.
- Replacing the line with `redir * /admin/ 308` made validation pass.

## Root Cause
An unvalidated Caddyfile edit was left on disk while the proxy kept running with its previously loaded configuration.

## Prevention / Rule
**Guardrail:** Every Caddyfile deployment must pass `caddy validate` using the deployed image before the file is promoted or the proxy is restarted.

This rejects invalid syntax before a restart can turn a latent config error into a site outage.

## Solution
### Immediate Fix
Backed up the original Caddyfile and changed only the redirect to `redir * /admin/ 308`. Validation with the deployed image now returns `Valid configuration`.

### Long-term Fix
Add Caddyfile validation as a deployment gate and verify the proxy after config changes.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- [Host Caddy Displaced the Docker Reverse Proxy](RESTK-2026-11-02-host-caddy-displaced-docker-proxy.md)

## References
- Production Caddy validation and Caddyfile diff, checked 2026-11-02.

---

**Resolved By:** Codex
**Time to Resolution:** Same session
