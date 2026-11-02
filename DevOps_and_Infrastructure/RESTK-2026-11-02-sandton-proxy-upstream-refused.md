# Sandton Proxy Upstream Refuses Connections

**Date:** 2026-11-02
**Project:** RESTK
**Environment:** Production
**Severity:** Medium
**Status:** Investigating

## Summary
The Sandton Caddy route returns HTTP 502 because the configured host upstream on port 8080 refuses connections.

## Symptoms
- `sandtonumc.co.zw` returned 502 through the restored proxy.
- Caddy logged `dial tcp 10.0.0.1:8080: connect: connection refused`.

## Environment Details
- **Server/Host:** `restk-vps`
- **Services Affected:** Sandton public route
- **Related Components:** Caddyfile `host.docker.internal:8080` upstream
- **Time First Observed:** 2026-11-02 09:04 UTC

## Investigation Steps
### 1. Initial Diagnosis
Probed the route through the proxy with its real SNI name.

### 2. Root Cause Analysis
Read the Caddy upstream and its connection error.

```bash
curl --resolve sandtonumc.co.zw:443:127.0.0.1 https://sandtonumc.co.zw/
docker exec caddy-proxy tail /var/log/caddy/access.log
```

### 3. Key Findings
- TLS terminates at Caddy.
- The upstream TCP connection is refused.
- The upstream is separate from the reboot port conflict.

## Root Cause
No service accepts the proxy's connection at `host.docker.internal:8080` at the time of inspection.

## Prevention / Rule
**Guardrail:** Probe each configured proxy upstream from the proxy network before declaring a route healthy.

This detects a missing listener even when the proxy and TLS are healthy.

## Solution
### Immediate Fix
Pending identification of the intended Sandton service; no change made during reboot recovery.

### Long-term Fix
Restore the intended upstream or update the Caddy target, then verify the public route.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Production Caddy error log, 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending
