# Stale Legacy Blue-Green Student Workers Remain Running

**Date:** 2026-10-15
**Project:** HBEC
**Environment:** Production VPS
**Severity:** Medium
**Status:** Resolved

## Summary
The VPS still runs `bg-student-beat` and `bg-student-worker` from the old
`hbec-bluegreen` Compose project. Both have been running for three days,
report `unhealthy`, and use the obsolete
`ghcr.io/rest-creator/hbec-student-backend:prod-promote-6a151782` image.
The current production services are the healthy `hbec-*` containers managed
by `/opt/hbec/docker-compose.production.yml`.

## Symptoms
- `bg-student-beat` and `bg-student-worker` are shown as unhealthy.
- Their health checks repeatedly fail to connect to `localhost:8000`.
- The containers continue running Celery Beat and Celery Worker processes
  despite the failed health checks.
- The current `hbec-student-beat` and `hbec-student-worker` services are
  healthy on revision `1a3b4ec`.

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** Legacy Student Backend Beat and Worker
- **Related Components:** Docker Compose project `hbec-bluegreen`,
  `/sdb-disk/hbec-bluegreen/docker-compose.bluegreen.yml`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Compared container names, Compose labels, image revisions, health states, and
the active deployment marker.

### 2. Root Cause Analysis
The containers belong to the old `hbec-bluegreen` project, not the current
`hbec` project. Their environment points to the old project's internal
`postgres` and `redis` services, confirming that they are isolated from the
current production dependency containers. The legacy Compose health check
incorrectly probes `localhost:8000` inside Celery-only containers, where no
HTTP server listens.

### 3. Key Findings
- Active color is blue, revision `1a3b4ec`.
- Current student Beat and Worker are healthy and use
  `ghcr.io/rest-creator/hbec-student-backend:sha-1a3b4ec`.
- Legacy containers use the `hbec-bluegreen-net` network and the old
  `prod-promote-6a151782` image.
- The old project also has its own PostgreSQL and Redis containers, so these
  workers are not the live production workers.

## Root Cause
The former blue-green deployment stack was left running after the current
`/opt/hbec` deployment became authoritative. Its Celery-only services retain
an HTTP health check that can never pass, leaving stale containers consuming
host resources and creating misleading unhealthy-container alerts.

## Prevention / Rule
**Guardrail:** Every deployment stack must have one authoritative Compose
project and a post-cutover check that fails if any obsolete project retains
running application containers.

This prevents an old stack from remaining active after deployment migration
and makes stale workers visible before they consume resources or confuse
operational diagnosis.

## Solution

### Immediate Fix
The two stale containers were removed after confirming that the current
`hbec` Compose project owns the live blue deployment and that the legacy
containers used an isolated network and obsolete image. The current student
Beat and Worker remained healthy after removal.

### Long-term Fix
Retire the remaining `hbec-bluegreen` Compose project components and prune
its unused images only after confirming no other legacy service is required
for rollback. The current production deployment is unaffected by the removed
worker and Beat containers.

## Prevention
- [x] Confirm the old stack is not needed for rollback
- [x] Stop and remove the stale legacy worker and Beat containers
- [ ] Prune its obsolete images after confirming no containers reference them
- [ ] Add a deployment guard against multiple authoritative Compose projects
- [ ] Correct health checks for Celery-only services in any retained stack

## Related Issues
- None.

## References
- `docker-compose.bluegreen.yml` in `/sdb-disk/hbec-bluegreen`
- `/opt/hbec/docker-compose.production.yml`
- VPS markers: `/opt/hbec/active_color`, `.sha_blue`, `.sha_green`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
