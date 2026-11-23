# Healthchecks using "localhost" reported false-unhealthy on IPv4-only services

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps)
**Severity:** Medium
**Status:** Resolved

## Summary
Both the frontend and backend containers' Docker healthchecks (and the deploy workflow's own smoke-test step) used `http://localhost`. In both containers, the resolver lists `::1` before `127.0.0.1`, and both services (nginx, uvicorn) listen IPv4-only — so the healthcheck tried the v6 loopback, got a bare "connection refused," and reported the container unhealthy while the real service answered every actual request fine.

## Symptoms
- `docker inspect --format '{{.State.Health.Status}}'` showed `unhealthy` with `FailingStreak` climbing.
- The health log's `Output` was `wget: can't connect to remote host: Connection refused` on every attempt.
- Meanwhile `docker logs` on the same container showed real HTTP requests being served successfully (nginx access log had a live `GET / HTTP/1.1 200` from an external client at the time).

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** hbca-classroom-frontend, hbca-classroom-backend
- **Related Components:** `ops/deploy/docker-compose.production.yml` healthchecks, `.github/workflows/deploy.yml` smoke-test step
- **Time First Observed:** 2026-11-23, manual verification pass

## Investigation Steps

### 1. Initial Diagnosis
Nginx worker processes were clearly running (`docker logs` showed them starting, and a real request being served), contradicting the "unhealthy"/"connection refused" status — pointed straight at the healthcheck command itself being wrong, not the service.

### 2. Root Cause Analysis
```bash
docker exec hbca-classroom-frontend-blue wget -qO- http://localhost:80
# wget: can't connect to remote host: Connection refused
docker exec hbca-classroom-frontend-blue wget -S -O- http://127.0.0.1:80/
# HTTP/1.1 200 OK ...
docker exec hbca-classroom-frontend-blue sh -c 'netstat -tlnp'
# tcp  0  0  0.0.0.0:80  0.0.0.0:*  LISTEN  1/nginx: master pro
# (no ::  entry at all — IPv4 only)
```

### 3. Key Findings
- `localhost` resolved to `::1` first inside the container; nginx had no IPv6 listener at all.
- The exact same pattern existed independently in the backend's compose healthcheck and in `deploy.yml`'s own smoke-test step (three separate places with the identical bug, not one shared piece of code).

## Root Cause
Alpine/BusyBox (and Python's `urllib`) resolve `localhost` to whatever order the container's resolver returns, which isn't guaranteed to favor `127.0.0.1` — and neither service bound an IPv6 listener to match.

## Prevention / Rule
**Guardrail:** Never use the hostname `localhost` in a container-internal healthcheck or smoke test; always use the literal `127.0.0.1` (or `0.0.0.0` where appropriate) so the check cannot silently pick a loopback address the service isn't listening on.

## Solution

### Immediate Fix
Replaced `http://localhost` with `http://127.0.0.1` in both compose healthchecks and in `deploy.yml`'s smoke-test step (three locations total).

### Long-term Fix
None further needed — this is now the standing convention per the guardrail above.

## Prevention
- [x] Configuration changes needed — all three locations fixed
- [ ] Monitoring/alerts to add
- [x] Documentation to update — noted inline as code comments at each fix site
- [x] Code changes required

## Related Issues
- None

## References
- `ops/deploy/docker-compose.production.yml`, `.github/workflows/deploy.yml`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~10 minutes
