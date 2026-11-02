# ProjectFlow Stack Stopped After VPS Restart

**Date:** 2026-11-02
**Project:** ProjectFlow
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
ProjectFlow's frontend, backend, scheduler, and database containers all stopped when the VPS restarted and did not return because their restart policy is `no`.

## Symptoms
- Frontend, backend, and database exited at 2026-11-01 11:39 UTC.
- Scheduler exited with code 137 at the same time.
- No ProjectFlow application container is running.

## Environment Details
- **Server/Host:** `server1.tesemarket.com` (`restk-vps`)
- **Services Affected:** ProjectFlow frontend, backend, scheduler, database
- **Related Components:** Docker Compose restart policies and host reboot
- **Time First Observed:** 2026-11-02 08:48 UTC

## Investigation Steps
### 1. Initial Diagnosis
Compared `docker ps -a` with host uptime.

### 2. Root Cause Analysis
`docker inspect` shows each ProjectFlow container has restart policy `no` and stopped at the restart time.

```bash
docker ps -a --filter label=com.docker.compose.project=projectflow
docker inspect projectflow-backend-1 projectflow-frontend-1 projectflow-scheduler-1 projectflow-db-1
```

### 3. Key Findings
- The four containers stopped together.
- The stack did not automatically restart.
- The public ProjectFlow route is also affected by the separate Caddy conflict.

## Root Cause
The deployed ProjectFlow stack has no automatic restart policy after host restart.

## Prevention / Rule
**Guardrail:** Validate that each long-running production Compose service has an explicit restart policy and verify the stack after host reboot.

This prevents an otherwise clean reboot from leaving the application stopped.

## Solution
### Immediate Fix
Pending operational restart; no production changes made during this read-only audit.

### Long-term Fix
Set appropriate Compose restart policies and add a post-reboot service check.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- [Host Caddy Displaced the Docker Reverse Proxy](RESTK-2026-11-02-host-caddy-displaced-docker-proxy.md)

## References
- Production Docker state and inspect output, checked 2026-11-02.

---

**Resolved By:** Pending
**Time to Resolution:** Pending
