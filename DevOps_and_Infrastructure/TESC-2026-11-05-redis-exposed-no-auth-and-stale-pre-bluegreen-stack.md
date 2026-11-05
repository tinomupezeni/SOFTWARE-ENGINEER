# Redis exposed on 0.0.0.0 with no auth; stale pre-blue/green stack still running on tesc-prod

**Date:** 2026-11-05
**Project:** TESC (ScalarEye)
**Environment:** Production (tesc-prod, 10.50.200.35)
**Severity:** High
**Status:** Investigating

## Summary
A routine SSH audit of tesc-prod (triggered by a "read the codebase and check
out production" request, no incident reported) found two issues: (1)
`tesc-main-redis-1` is bound to `0.0.0.0:6379` with no `requirepass` set —
`redis-cli ping` from the host returns `PONG` unauthenticated; and (2) the
pre-blue/green compose stack (`tesc-main-backend-1`, `tesc-main-frontend-*-1`,
image tag `fcf6985`) is still running 13 days after the blue/green cutover
and still has its backend and both frontends bound directly to host ports
(`8000`, `8081`, `8082`), bypassing the nginx front door and the blue/green
color that's actually meant to be live.

## Symptoms
None reported by users — found via infrastructure audit, not an incident.

## Environment Details
- **Server/Host:** tesc-prod (10.50.200.35)
- **Services Affected:** `tesc-main-redis-1`, `tesc-main-backend-1`,
  `tesc-main-frontend-client-v2-1`, `tesc-main-frontend-admin-v2-1`
- **Related Components:** blue/green deploy tooling
  (`scripts/bluegreen-cutover.sh`, `scripts/bluegreen-deploy.sh`,
  `docker-compose.bluegreen.yml`)
- **Time First Observed:** 2026-11-05, during routine audit

## Investigation Steps

### 1. Initial Diagnosis
`docker ps -a` on tesc-prod showed two full application stacks running
concurrently: the blue/green pair (`backend-blue`/`backend-green`,
`frontend-*-v2-blue`/`-green`, no host ports — correct, nginx is the only
front door for these) and a second, older `tesc-main-*` stack still up and
exposing ports directly.

### 2. Root Cause Analysis
```bash
docker ps --format '{{.Names}}\t{{.Ports}}'
docker exec tesc-main-redis-1 redis-cli ping   # -> PONG, no auth required
docker inspect tesc-main-nginx-1 --format '{{json .Mounts}}'
```
The live nginx config (`/home/user/Documents/TESC-main/nginx/nginx.conf`,
rendered by `scripts/render_bluegreen_nginx.py`) correctly routes
`tesc.zchpc.ac.zw` / `tesc-inst.zchpc.ac.zw` to `backend-blue` /
`frontend-*-v2-blue`, matching `active_color=blue` and `.sha_blue=94bf94e` —
the blue/green mechanism itself is working as designed. The old `tesc-main-*`
stack is a separate, un-retired docker-compose project (`docker-compose.yml`,
no color suffix) that predates the blue/green migration
([[TESC-2026-10-26-blue-green-production-deployment-guide]] if that report
exists) and was apparently never torn down after the cutover. Because its
backend/frontend containers publish host ports directly, they are reachable
by IP:port without going through nginx, auth-adjacent header handling, or
whichever color is supposed to be "live" — an unaudited second copy of the
app serving (likely stale) code. Redis has no password at all, independent
of blue/green, and is bound to all interfaces rather than loopback/internal
network only.

### 3. Key Findings
- `tesc-main-redis-1` accepts unauthenticated commands from any host that
  can reach port 6379 on tesc-prod.
- The pre-blue/green `tesc-main-backend-1` (`tinotenda762/tesc-backend:fcf6985`)
  and both `tesc-main-frontend-*-1` containers are still running and
  directly reachable on `:8000`, `:8081`, `:8082`, bypassing nginx entirely.
- Could not confirm from this session whether host firewall rules restrict
  these ports to trusted networks — `ufw`/`iptables` both require root,
  which this session did not have.
- The database credential for `tesc_db` was also observed to be a weak,
  guessable value during this audit; not reproduced here since this file is
  committed to a repo — see Prevention below.

## Root Cause
The old pre-blue/green docker-compose stack was never stopped/removed after
the blue/green deployment model was adopted, and Redis was deployed without
`requirepass` from the start. Neither is a blue/green-specific defect — the
blue/green cutover logic itself is functioning correctly.

## Prevention / Rule
**Guardrail:** Add a step to `scripts/bluegreen-cutover.sh` (or a follow-up
script) that, after a successful cutover is confirmed stable, stops and
removes any container not part of `docker-compose.bluegreen.yml` or the
shared singletons (`db`, `redis`, `nginx`) — i.e. make "retire the old
stack" a scripted, required step rather than a manual aside. Separately, add
a CI/deploy-time check (or a `scripts/` preflight) that fails if Redis is
reachable without `requirepass`, and rotate the Postgres password to a
generated, non-guessable value stored only in the prod `.env` (not
hardcoded/reused across environments).

This closes the gap because the current process treats stack retirement and
credential strength as "remember to do it" rather than something enforced
by tooling.

## Solution

### Immediate Fix
None applied yet — flagged for the user to decide on timing (stopping the
old stack and rotating credentials both affect a live production system).

### Long-term Fix
- Stop and remove `tesc-main-backend-1`, `tesc-main-frontend-client-v2-1`,
  `tesc-main-frontend-admin-v2-1` once confirmed nothing depends on their
  direct host ports.
- Set `requirepass` on `tesc-main-redis-1` (and update `REDIS_URL` /
  `CELERY_BROKER_URL` env vars across blue/green services to include it),
  or bind Redis to the internal docker network only (drop the host port
  publish).
- Rotate the `tesc_db` Postgres password to a generated secret.

## Prevention
- [ ] Script-enforced retirement of the pre-blue/green stack post-cutover
- [ ] `requirepass` on Redis + updated connection URLs
- [ ] Postgres credential rotation
- [ ] Firewall rule audit (needs root on tesc-prod — not available this session)

## Related Issues
- Blue/green deployment work: recent `staging`/`main` commits decomposing
  `build_queryset`/`bulk_create_from_file`/`get_queryset` and the
  docker-compose.prod.yml retirement.

## References
- `scripts/bluegreen-cutover.sh`, `scripts/render_bluegreen_nginx.py`
- tesc-prod `/home/user/Documents/TESC-main/`

---

**Resolved By:** Found by Claude (Sonnet 5) during audit requested by Tinotenda Mupezeni
**Time to Resolution:** Not yet resolved — flagged, not fixed
