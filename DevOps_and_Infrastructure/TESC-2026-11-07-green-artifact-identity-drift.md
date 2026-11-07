# Green deployment contains mixed artifact identities

**Date:** 2026-11-07
**Project:** TESC
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The inactive green blue-green deployment on `tesc-prod` is not a single coherent
release. Its backend and frontend services use different commit tags, so the
green environment must not receive public traffic until all components are
rebuilt and verified from one source commit.

## Symptoms
- Public traffic is routed to blue `94bf94e`.
- Green backend and worker run `c6bac5c`.
- Green client frontend runs `e096a00`.
- Green admin frontend runs `2d5e497`.
- The green marker contains only `c6bac5c`, which does not describe the
  frontend artifacts.

## Environment Details
- **Server/Host:** `tesc-prod` (`10.50.200.35`)
- **Services Affected:** `backend-green`, `celery-worker-green`,
  `frontend-client-v2-green`, `frontend-admin-v2-green`
- **Related Components:** `docker-compose.bluegreen.yml`,
  `scripts/bluegreen-deploy.sh`, `scripts/bluegreen-cutover.sh`
- **Time First Observed:** 2026-11-07 18:20 +02:00

## Investigation Steps

### 1. Initial Diagnosis
Checked the active color, per-color SHA markers, running containers, image
references, and Docker image IDs on `tesc-prod`.

### 2. Root Cause Analysis
The green services were recreated from different image tags. The deployment
marker was updated to `c6bac5c`, but the frontend services still reference
older green tags.

```bash
docker ps --format '{{.Names}}|{{.Image}}'
docker inspect -f '{{.Name}}|{{.Config.Image}}|{{.Image}}' <container>
cat active_color .sha_blue .sha_green
```

### 3. Key Findings
- All eight colored application containers are running.
- `scripts/check_compose_colors.py` passes structural checks, but it does not
  compare the running image tag of every service in one color.
- Migration plans report no pending operations in either colored backend.

## Root Cause
The release identity is recorded per color, but runtime verification does not
enforce that every backend, worker, client, and admin image in that color
shares the same deployment commit.

## Prevention / Rule
**Guardrail:** Make the deploy and cutover checks enumerate every colored
service, require the same seven-character release tag for the whole target
color, and refuse cutover when any running image tag differs from the color
marker.

This closes the gap between a successful partial image build and a falsely
valid green environment.

## Solution

### Immediate Fix
No production mutation was performed. Blue remains active; green was not
promoted.

### Long-term Fix
Add runtime artifact-parity validation to the blue-green deploy/cutover path
and make the marker update the final step after all four target services pass
identity, migration, readiness, and smoke checks.

## Prevention
- [ ] Add a runtime artifact-parity guard to deployment scripts
- [ ] Add a cutover refusal for mixed target-color tags
- [ ] Add an alert/report when a color marker disagrees with running images

## Related Issues
- `TESC-2026-11-05-redis-exposed-no-auth-and-stale-pre-bluegreen-stack.md`

## References
- `/home/user/Documents/TESC-main/docker-compose.bluegreen.yml`
- `/home/user/Documents/TESC-main/scripts/bluegreen-deploy.sh`
- `/home/user/Documents/TESC-main/scripts/bluegreen-cutover.sh`
- Production inspection on `tesc-prod`, 2026-11-07

---

**Resolved By:** Copilot
**Time to Resolution:** Not resolved; promotion blocked
