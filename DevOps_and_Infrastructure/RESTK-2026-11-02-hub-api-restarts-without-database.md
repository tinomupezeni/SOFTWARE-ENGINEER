# RESTK Hub API Restarts Without Its Database

**Date:** 2026-11-02
**Project:** RESTK
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The RESTK Hub API repeatedly exits because its configured database hostname `db` cannot resolve. Its database container has been stopped since June 2026; the web container is also stopped.

## Symptoms
- `restk-hub-api-1` is restarting with exit code 1 and over 1,200 restarts.
- Logs show `java.net.UnknownHostException: db` and Hibernate startup failure.
- `restk-hub-db-1` and `restk-hub-web-1` are exited.

## Environment Details
- **Server/Host:** `server1.tesemarket.com` (`restk-vps`)
- **Services Affected:** RESTK Hub API, web, database
- **Related Components:** Docker Compose service DNS and database startup
- **Time First Observed:** 2026-11-02 08:48 UTC

## Investigation Steps
### 1. Initial Diagnosis
Checked container states and restart counts.

### 2. Root Cause Analysis
API logs identify an unresolvable database host, consistent with its stopped database container.

```bash
docker ps -a --filter label=com.docker.compose.project=restk-hub
docker logs --tail 100 restk-hub-api-1
```

### 3. Key Findings
- Database stopped months ago.
- API restart policy keeps retrying without a dependency that can resolve.
- Web container is also stopped.

## Root Cause
The API depends on database service `db`, which is absent from the running Compose network.

## Prevention / Rule
**Guardrail:** Probe database DNS and connection before declaring Hub API deployment healthy, and alert when a persistent database container stops.

This exposes the missing dependency directly instead of leaving the API in a restart loop.

## Solution
### Immediate Fix
Pending database and application recovery; no production changes made during this read-only audit.

### Long-term Fix
Reconcile the deployed Hub stack and its database dependency, then verify the full request path.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None identified.

## References
- Production Docker logs and inspect output, checked 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending
