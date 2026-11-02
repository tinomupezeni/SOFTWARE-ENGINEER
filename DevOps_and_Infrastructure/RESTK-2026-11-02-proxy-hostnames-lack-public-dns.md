# Configured Proxy Hostnames Lack Public DNS

**Date:** 2026-11-02
**Project:** RESTK
**Environment:** Production
**Severity:** Medium
**Status:** Investigating

## Summary
Several hostnames in the production Caddyfile have no public DNS record, preventing certificate issuance and external access.

## Symptoms
- HTTPS handshakes fail for some configured hostnames without cached certificates.
- ACME reports DNS NXDOMAIN for `maricho.restksolutions.co.zw`, `swaposell.restksolutions.co.zw`, `projectflow.restksolutions.com`, and `tese.restksolutions.co.zw`.

## Environment Details
- **Server/Host:** `restk-vps`
- **Services Affected:** Listed public hostnames
- **Related Components:** Caddyfile host blocks, external DNS zones, ACME
- **Time First Observed:** 2026-11-02 09:04 UTC

## Investigation Steps
### 1. Initial Diagnosis
Probed configured HTTPS hosts through the restored proxy.

### 2. Root Cause Analysis
Read Caddy's ACME errors for each failed hostname.

```bash
docker exec caddy-proxy tail /var/log/caddy/access.log
```

### 3. Key Findings
- ACME reports NXDOMAIN for the listed names.
- Other configured domains with valid DNS and cached certificates respond normally.
- This is independent of the reboot port conflict.

## Root Cause
Caddy attempts to serve hostnames whose public DNS records do not exist.

## Prevention / Rule
**Guardrail:** Validate DNS A/AAAA resolution for every new production Caddy hostname before adding the route.

This prevents an unissuable TLS configuration and an unreachable public hostname.

## Solution
### Immediate Fix
Pending DNS owner review; no DNS changes made during reboot recovery.

### Long-term Fix
Create records for intended hostnames and remove retired hostnames from the Caddyfile, then verify public HTTPS.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Production Caddy ACME errors, 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending
