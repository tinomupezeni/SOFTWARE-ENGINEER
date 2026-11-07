# Idle-color deployment collided with existing named containers

**Date:** 2026-11-07
**Project:** TESC
**Environment:** Production
**Severity:** Medium
**Status:** Workaround Applied

## Summary
The blue-green deployment script failed while starting the updated green services because the temporary deployment checkout derived a different Docker Compose project name, while the existing green containers had fixed names and belonged to the `tesc-main` project.

## Symptoms
- The build and migration safety gate passed.
- `docker compose up` failed with `Conflict. The container name "/backend-green" is already in use`.
- Existing green services remained on the previous release until the deployment was retried with the production Compose project name.

## Environment Details
- **Server/Host:** `tesc-prod`
- **Services Affected:** `backend-green`, `celery-worker-green`, `frontend-client-v2-green`, `frontend-admin-v2-green`
- **Related Components:** `docker-compose.bluegreen.yml`, `scripts/bluegreen-deploy.sh`
- **Time First Observed:** 2026-11-07

## Investigation Steps

### 1. Initial Diagnosis
Inspected the existing green containers and their Compose labels after the failed deployment.

### 2. Root Cause Analysis
```bash
docker inspect backend-green
docker compose -f docker-compose.bluegreen.yml up -d --no-deps --wait ...
```

### 3. Key Findings
- Existing green containers were owned by the `tesc-main` Compose project.
- A temporary worktree caused Compose to derive `tesc-deploy-0a1a76d` as the project name.
- Fixed `container_name` values made the project-name mismatch non-reconcilable during recreate.

## Root Cause
The deployment script assumes that its working directory produces the same Compose project identity as the long-lived production checkout. Running it from a temporary worktree changed that identity even though the service names and fixed container names remained unchanged.

## Prevention / Rule
**Guardrail:** Set and validate `COMPOSE_PROJECT_NAME=tesc-main` for every blue-green Compose invocation, independent of the checkout directory.

This makes container ownership stable across normal checkouts and temporary deployment worktrees, preventing name collisions during idle-color replacement.

## Solution

### Immediate Fix
Retried the deployment with `COMPOSE_PROJECT_NAME=tesc-main`; Compose recreated the four green services successfully at `0a1a76d`.

### Long-term Fix
Update the deployment script to set the production Compose project name explicitly and add a preflight check that existing colored containers belong to that project.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- None

## References
- `TESC/scripts/bluegreen-deploy.sh`
- `TESC/docker-compose.bluegreen.yml`

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
