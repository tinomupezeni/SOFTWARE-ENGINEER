# HBCA staging school API hostname does not resolve

**Date:** 2026-11-06
**Project:** HBEC
**Environment:** Staging
**Severity:** Low
**Status:** Investigating

## Summary
The staging Caddy configuration defines `staging-school-api.hbca.tech`, but DNS did not resolve that hostname during a staging API inventory. The schools API is reachable through the `staging-school.hbca.tech/api/v1/` route instead.

## Symptoms
- `curl` reports `Could not resolve host: staging-school-api.hbca.tech`.
- Consumers cannot use the dedicated schools API hostname described in the Caddy configuration and OpenAPI source file.

## Environment Details
- **Server/Host:** hbca-vps; staging-school-api.hbca.tech
- **Services Affected:** Schools backend staging external access
- **Related Components:** Caddy staging virtual host, DNS zone, schools backend
- **Time First Observed:** 2026-11-06

## Investigation Steps

### 1. Initial Diagnosis
Read the active Caddyfile in `hbec-gateway`: it routes `staging-school-api.hbca.tech` to `hbec-schools-backend-green:8000`.

### 2. Root Cause Analysis
The hostname failed DNS resolution from the VPS. The DNS zone was not inspected, so the precise missing or incorrect record remains to be confirmed.

```bash
docker exec hbec-gateway sed -n '89,115p' /etc/caddy/Caddyfile
curl -fsS https://staging-school-api.hbca.tech/openapi.json
```

### 3. Key Findings
- Caddy has a virtual host for the dedicated staging API hostname.
- The hostname cannot be resolved during this inspection.
- `staging-school.hbca.tech` is the working staging entry point for `/api/*`.

## Root Cause
The deployed proxy configuration and DNS are out of sync. The exact DNS record state needs verification with the DNS provider.

## Prevention / Rule
**Guardrail:** Add a deployment check that resolves every hostname rendered into the Caddyfile and fails promotion when any public staging hostname has no DNS answer.

This catches proxy and DNS drift before an API hostname is handed to an integrator.

## Solution

### Immediate Fix
Use `https://staging-school.hbca.tech/api/v1/` for school integration testing. No DNS changes were made during this read-only inventory.

### Long-term Fix
Create or correct the DNS record for `staging-school-api.hbca.tech`, then verify TLS and an authenticated schools API call.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None known.

## References
- Active Caddyfile on hbca-vps, read 2026-11-06
- `docs/hbca-staging-api-catalog-2026-11-06.md`

---

**Resolved By:** Not yet resolved
**Time to Resolution:** Pending
