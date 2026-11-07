# Production Images Missing Revision Labels

**Date:** 2026-11-07
**Project:** LEC Virtual Labs
**Environment:** Production (`hbca-vps`)
**Severity:** Medium
**Status:** Investigating

## Summary

The blue production images were built with immutable `sha-4b2cb34` tags, but
their OCI `org.opencontainers.image.revision` labels are `unknown`. The
Compose build argument defaults to `unknown`, and
`scripts/deploy/deploy-color.sh` does not export `GIT_SHA` before building.
The deployment is stable, but the label-based artifact observer cannot verify
the source revision.

## Symptoms

- `vlabs-backend-blue` image: `vlabs-backend:sha-4b2cb34`
- `vlabs-frontend-blue` image: `vlabs-frontend:sha-4b2cb34`
- Both `org.opencontainers.image.revision` labels report `unknown`.

## Environment Details

- **Server/Host:** `hbca-vps` (`/sdb-disk/projects/vlabs`)
- **Services Affected:** Deployment artifact observability
- **Related Components:** `scripts/deploy/deploy-color.sh`,
  `docker-compose.production.yml`, both Dockerfiles
- **Time First Observed:** 2026-11-07 during the blue deployment

## Investigation Steps

### 1. Initial Diagnosis

Inspected the candidate container image tags and OCI labels before and after
cutover.

### 2. Root Cause Analysis

```bash
docker inspect -f '{{.Config.Image}} {{index .Config.Labels "org.opencontainers.image.revision"}}' \
  vlabs-backend-blue vlabs-frontend-blue
grep -n 'GIT_SHA' docker-compose.production.yml scripts/deploy/deploy-color.sh
```

### 3. Key Findings

- The deploy script derives `TAG=sha-<short SHA>` but does not set `GIT_SHA`.
- Compose passes `${GIT_SHA:-unknown}` to both image builds.
- The image tag identifies the deployed source for this release, but the
  metadata observer reports no revision.

## Root Cause

The deployment path has two independent source-identity channels, and only the
image tag is populated. The Dockerfile label channel is left at its Compose
default because the deploy script does not export the source SHA.

## Prevention / Rule

**Guardrail:** Require the deploy script to export the full `GIT_SHA` and make
the release preflight fail if either built image's revision label differs from
the checkout SHA.

This makes the label observer authoritative instead of allowing an
`unknown`-labeled image to pass artifact verification.

## Solution

### Immediate Fix

No runtime change was needed; the immutable image tags and verified checkout
SHA identified the deployed release, and production smoke checks passed.

### Long-term Fix

Pass `GIT_SHA="$(git rev-parse HEAD)"` through the deployment build and add a
post-build label parity check.

## Prevention

- [ ] Export `GIT_SHA` in `deploy-color.sh`.
- [ ] Fail deployment when image revision labels are missing or mismatched.
- [ ] Record image tags and labels in the release evidence.

## References

- `scripts/deploy/deploy-color.sh`
- `docker-compose.production.yml`
- `backend/Dockerfile`
- `frontend/Dockerfile`

---

**Resolved By:** Pending follow-up
**Time to Resolution:** Open
