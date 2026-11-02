# Lakeisha Proxy Upstreams Are Unresolvable

**Date:** 2026-11-02
**Project:** RESTK
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The RESTK Caddy proxy returns HTTP 502 for the Lakeisha storefront and admin routes because its configured upstream names cannot resolve on `proxy-tier`.

## Symptoms
- `lakeishacupcakery.co.zw` and `admin.lakeishacupcakery.co.zw` return 502.
- Caddy logs report `lookup lakeishas-frontend ... no such host` and the same for `lakeishas-admin`.

## Environment Details
- **Server/Host:** `restk-vps`
- **Services Affected:** Lakeisha storefront and admin public routes
- **Related Components:** Caddyfile upstreams, Lakeisha Docker networks
- **Time First Observed:** 2026-11-02 09:04 UTC

## Investigation Steps
### 1. Initial Diagnosis
Probed the HTTPS routes through localhost with the real SNI names.

### 2. Root Cause Analysis
Compared Caddy errors and `docker network inspect proxy-tier` with the Lakeisha container network attachments.

```bash
docker network inspect proxy-tier
docker inspect lakeisha-frontend-1 lakeisha-admin-frontend-1
curl --resolve lakeishacupcakery.co.zw:443:127.0.0.1 https://lakeishacupcakery.co.zw/
```

### 3. Key Findings
- Lakeisha containers are running but absent from `proxy-tier`.
- Caddy uses `lakeishas-frontend` and `lakeishas-admin`, which do not resolve there.
- The issue is independent of the reboot port conflict.

## Root Cause
The proxy configuration references upstream DNS names that are not present on its Docker network.

## Prevention / Rule
**Guardrail:** Validate every Caddy `reverse_proxy` hostname against the proxy network's deployed service aliases before rollout.

This catches unreachable upstreams before public routes return 502.

## Solution
### Immediate Fix
Pending Lakeisha route reconciliation; no change made during reboot recovery.

### Long-term Fix
Connect Lakeisha services to `proxy-tier` with stable aliases and update the Caddyfile to those aliases, then test storefront and admin journeys.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Production Caddy error log and Docker network inspection, 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending
