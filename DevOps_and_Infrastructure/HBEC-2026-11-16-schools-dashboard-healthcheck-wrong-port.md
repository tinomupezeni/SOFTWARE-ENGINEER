# schools-dashboard's new healthcheck targeted the wrong port on its first real deploy run

**Date:** 2026-11-16
**Project:** HBEC
**Environment:** Production VPS (hbca-vps), building the inactive blue-green color
**Severity:** Low
**Status:** Resolved

## Summary
The `healthcheck:` added to `schools-dashboard`'s compose services earlier
this session (`HBEC-2026-11-16-schools-deploy-verification-gaps.md`) pointed
`wget --spider` at `http://127.0.0.1:5173/`, copied from the service's
Dockerfile `EXPOSE 5173`. On the first real `manual-deploy-color.sh` run
with it, `hbec-schools-dashboard-blue` was flagged unhealthy and the deploy
correctly stopped before `verify-revisions`/`verify-service-links` ran.
Container logs showed the actual bound address: `Local:
http://localhost:8080/` — the `vite-tanstack-config` wrapper's dev server
binds 8080, not Vite's usual 5173. `docker-compose.production.yml`'s Caddy
routes for this service had always correctly targeted 8080; only the new
healthcheck (and the Dockerfile's informational `EXPOSE`) were wrong.

## Symptoms
- `manual-deploy-color.sh` exited after `docker compose up --wait` reported
  `container hbec-schools-dashboard-blue is unhealthy`, before any later
  verification step ran.

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec`.
- **Services Affected:** DevOps/Infrastructure (deploy pipeline healthcheck).
- **Related Components:** `docker-compose.production.yml`
  (`x-schools-dashboard-healthcheck` anchor), `SCHOOLS/school_dashboard/Dockerfile`.
- **Time First Observed:** 2026-11-16, first `manual-deploy-color.sh` run
  after adding the healthcheck.

## Investigation Steps

### 1. Initial Diagnosis
`sudo docker inspect hbec-schools-dashboard-blue --format '{{json
.State.Health}}'` showed every probe failing with `Connection refused` on
5173.

### 2. Root Cause Analysis
`sudo docker logs hbec-schools-dashboard-blue` showed Vite's own startup
line binding 8080, not 5173 — confirming the healthcheck (and the
Dockerfile's `EXPOSE`) never matched the process's real listening port.

### 3. Key Findings
- The guardrail worked exactly as intended: it caught a real misconfigured
  healthcheck and stopped the deploy before it could proceed on a false
  "healthy" signal — the mechanism this session's earlier fix
  (`HBEC-2026-11-16-schools-deploy-verification-gaps.md`) existed to add.

## Root Cause
The healthcheck port was taken from the Dockerfile's `EXPOSE` directive
without verifying it against the process's actual bound port.

## Prevention / Rule
**Guardrail:** none beyond "verify a healthcheck against a real running
container before considering it done" — which this VPS run itself now
serves as the record of.

## Solution

### Immediate Fix
`docker-compose.production.yml`'s `schools-dashboard` healthcheck anchor
now targets `http://127.0.0.1:8080/`; `SCHOOLS/school_dashboard/Dockerfile`'s
`EXPOSE` corrected to 8080 with a comment explaining why, so the next
reader doesn't copy 5173 from it again.

### Long-term Fix
None beyond the fix itself — the same unresolved question from
`HBEC-2026-11-16-schools-dashboard-dev-server-in-production.md` (whether
this should run a Nitro production build instead of `npm run dev`) still
stands; this entry only fixes the healthcheck port.

## Prevention
- [x] Healthcheck and `EXPOSE` corrected to the real port (8080).

## Related Issues
- `HBEC-2026-11-16-schools-deploy-verification-gaps.md` — the healthcheck
  this fixes was added there.
- `HBEC-2026-11-16-schools-dashboard-dev-server-in-production.md` — the
  open question about whether this service should run a production build.

## References
- `docker-compose.production.yml`
- `SCHOOLS/school_dashboard/Dockerfile`

---

**Resolved By:** Local code fix, 2026-11-16
**Time to Resolution:** Same deploy run as discovery
