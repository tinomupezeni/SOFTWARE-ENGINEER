# Sentinel Controller Fails Database Authentication

**Date:** 2026-11-02
**Project:** RESTK
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The Sentinel monitoring controller repeatedly fails to authenticate to `shared-postgres` as user `sentinel`, then restarts. The database container itself is running.

## Symptoms
- `sentinel-controller` had 3,694 restarts at inspection.
- Logs report PostgreSQL SQLSTATE 28P01: password authentication failed for user `sentinel`.

## Environment Details
- **Server/Host:** `server1.tesemarket.com` (`restk-vps`)
- **Services Affected:** Sentinel controller monitoring functions
- **Related Components:** `shared-postgres`, Sentinel credentials
- **Time First Observed:** 2026-11-02 08:49 UTC

## Investigation Steps
### 1. Initial Diagnosis
Checked controller status and restart count.

### 2. Root Cause Analysis
Logs show the database responds but rejects the controller's credentials.

```bash
docker inspect sentinel-controller
docker logs --tail 20 sentinel-controller
```

### 3. Key Findings
- `shared-postgres` is running.
- The controller receives a specific authentication rejection, not a connection refusal.
- The controller briefly reports running between retries.

## Root Cause
The controller's configured database password does not match the `sentinel` database role credential, or the role credential has drifted.

## Prevention / Rule
**Guardrail:** Verify Sentinel's database login with its deployed secret during rollout and alert on repeated controller restarts.

This catches credential drift before monitoring becomes unreliable.

## Solution
### Immediate Fix
Pending credential reconciliation; no production changes made during this read-only audit.

### Long-term Fix
Keep the controller secret and database role credential synchronized through deployment configuration.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Production Sentinel logs and Docker inspect output, checked 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending
