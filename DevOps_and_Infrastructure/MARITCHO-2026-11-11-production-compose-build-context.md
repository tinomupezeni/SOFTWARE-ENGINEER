# Maricho production deployment cannot use remote image promotion

**Date:** 2026-11-11
**Project:** MARITCHO
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Maricho's production Compose file builds the API and frontend from repository-relative
contexts. A VPS deployment modeled on ProjectFlow's image-upload workflow transfers
the Compose file and prebuilt images, not the full source tree, so the production
stack cannot be started from the uploaded deployment artifact as currently defined.

## Symptoms
- The production Compose file points `api` and `frontend` at local `build:` contexts.
- A remote host receiving only the Compose file and Docker images cannot resolve those
  build contexts.
- The deployment path has no immutable image identity or remote artifact verification.

## Environment Details
- **Server/Host:** Self-hosted VPS deployment target
- **Services Affected:** Maricho API and frontend
- **Related Components:** `deploy/production/docker-compose.yml`, deployment scripts
- **Time First Observed:** 2026-11-11

## Investigation Steps

### 1. Initial Diagnosis
Compared Maricho's production Compose configuration with ProjectFlow's
`docker-compose.prod.yml` and `deploy.sh` image-upload workflow.

### 2. Root Cause Analysis
ProjectFlow's remote deployment loads locally built Docker images and runs Compose
with `image:` references. Maricho's production Compose instead retains local
`build:` directives, coupling VPS startup to a source checkout that the deployment
workflow does not transfer.

```bash
rg -n "build:|image:" deploy/production/docker-compose.yml
```

### 3. Key Findings
- ProjectFlow uploads compressed, resumable Docker images and then starts the
  remote stack from image references.
- Maricho already has production health endpoints and a production volume/network
  layout suitable for the same workflow.
- The missing control is artifact promotion and identity verification, not a new
  application runtime.

## Root Cause
The production Compose contract describes a source-build deployment while the
intended VPS workflow is an image-promotion deployment.

## Prevention / Rule
**Guardrail:** Production Compose services must use explicit image tags supplied by
the deployment artifact, and the deployment script must verify the running image
references against the promoted tag before reporting success.

This prevents a remote deployment from silently rebuilding a different checkout or
failing because source build contexts are absent.

## Solution

### Immediate Fix
Changed production Compose to use `maricho-backend:${APP_VERSION}` and
`maricho-frontend:${APP_VERSION}` image references. Added a resumable image
uploader and deployment script that uploads the tagged images, validates the
remote configuration, runs the stack, checks migrations and readiness, verifies
the exact running image tags, and performs frontend smoke checks.

### Long-term Fix
Keep source builds in local/CI Compose files and make the production deployment
artifact self-contained: tagged images, production Compose, required configuration
preflight, migration confirmation, readiness checks, and frontend/backend smoke
checks.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- ProjectFlow reference: `projectflow_backend/deploy.sh`
- ProjectFlow reference: `projectflow_backend/deploy_upload.sh`

## References
- `/home/shadowe/Projects/MARITCHO/deploy/production/docker-compose.yml`
- `/home/shadowe/Projects/ProjectFlow/projectflow_backend/deploy.sh`
- `/home/shadowe/Projects/ProjectFlow/projectflow_backend/deploy_upload.sh`

---

**Resolved By:** Copilot
**Time to Resolution:** Same engineering session
