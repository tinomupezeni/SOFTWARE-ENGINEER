# Admin Frontend 502 Bad Gateway

**Date:** 2026-07-14
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The admin dashboard at `admin.hbca.tech` was returning an HTTP 502 Bad Gateway error. The root cause was that the `hbec-admin-frontend` Docker container was created but never started.

## Symptoms
- Navigating to `admin.hbca.tech` resulted in a 502 Bad Gateway error.
- The Caddy gateway logged: `dial tcp: lookup hbec-admin-frontend on 127.0.0.11:53: server misbehaving`.

## Environment Details
- **Server/Host:** hbec-vps
- **Services Affected:** `hbec-admin-frontend`, `hbec-gateway`
- **Related Components:** Caddy Reverse Proxy, Docker DNS
- **Time First Observed:** 2026-07-14 07:21

## Investigation Steps

### 1. Initial Diagnosis
Checked the Caddy logs (`docker logs hbec-gateway`) to see why it was throwing a 502. The logs indicated it couldn't resolve `hbec-admin-frontend`.

### 2. Root Cause Analysis
Checked the status of running containers using `docker ps`. The `hbec-admin-frontend` container was missing from the list. Ran `docker ps -a` to find it and discovered it was in a `Created` state.

```bash
# Commands used for investigation
docker logs --tail 20 hbec-gateway
docker ps -a | grep hbec-admin-frontend
```

### 3. Key Findings
- The `hbec-admin-frontend` container existed but was not running.
- Caddy could not proxy traffic because Docker DNS could not resolve a stopped container.

## Root Cause
An interrupted deployment or `docker compose` update left the `hbec-admin-frontend` container in a `Created` state instead of starting it.

## Prevention / Rule
**Guardrail:** replace `docker compose up -d` with `docker compose up -d --wait` in every deploy script, which blocks and fails the deploy if any service doesn't reach a confirmed `running`/healthy state — instead of returning immediately once containers are merely `Created`.

This directly closes the gap that let the deploy report success while the frontend container never actually started.

## Solution

### Immediate Fix
Manually started the container and verified connectivity.

```bash
# Commands used to fix
docker start hbec-admin-frontend
```

### Long-term Fix
Ensure deployment scripts include health checks and successfully complete the container lifecycle (e.g. `docker compose up -d --wait`).

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None

## References
- None

---

**Resolved By:** Antigravity Agent
**Time to Resolution:** 5 minutes
