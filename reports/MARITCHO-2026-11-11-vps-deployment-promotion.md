# Maricho VPS deployment promotion workflow

**Date:** 2026-11-11
**Project:** MARITCHO
**Type:** Deployment / Architecture Decision
**Status:** Completed

## Summary
Added a ProjectFlow-style self-hosted VPS deployment workflow for Maricho.
Production Compose now runs the exact tagged backend and frontend images built
by the deployment command, while the deployment script uploads those images
resumably and verifies configuration, dependencies, migrations, runtime image
identity, and frontend availability before reporting success.

## Context / Trigger
The user requested the same deployment-script and Docker setup pattern used by
ProjectFlow's `deploy.sh` and `deploy_upload.sh`. Comparison showed that
Maricho's production Compose still described a source-build deployment, which
was incompatible with a remote host receiving only the Compose file and
prebuilt Docker images.

## Scope
Included production Compose image promotion, resumable image upload, VPS
preflight and deployment checks, public frontend smoke validation, setup and
rollback documentation, and production environment example cleanup.

Excluded actual VPS promotion because no deployment host credentials or target
environment values were supplied. No application business logic, database
schema, or proxy configuration was changed.

## Method
Compared the ProjectFlow deployment scripts and production Compose contract with
Maricho's Dockerfiles, health endpoints, Alembic entrypoint, and production
environment requirements. Implemented the smallest compatible image-based
workflow, then validated shell syntax, Compose rendering, and both production
container builds.

## Decisions & Findings
- Production Compose uses immutable `APP_VERSION`-tagged images instead of
  repository-relative build contexts.
- The uploader uses compressed chunks, per-part checksums, retries, and image-ID
  deduplication so interrupted deployments can resume safely.
- Remote deployment fails for missing/placeholder production secrets and checks
  database readiness, API dependency readiness, Alembic head status, frontend
  rendering, and exact running image tags.
- A real VPS smoke journey remains a deployment-time check, not a local-build
  claim.

## Changes Made
- `deploy/production/docker-compose.yml`: switched API/frontend to tagged
  image references.
- `deploy/production/deploy_upload.sh`: added resumable compressed Docker image
  transfer and remote loading.
- `deploy/production/deploy.sh`: added build, upload, remote deployment,
  configuration preflight, migration/readiness checks, artifact identity
  checks, and public frontend smoke test.
- `deploy/production/README.md`: documented one-time VPS setup, deployment,
  required variables, and rollback.
- `deploy/production/.env.example`: removed the loopback OTLP default.

## Verification
- `bash -n deploy/production/deploy.sh deploy/production/deploy_upload.sh`
- `docker compose ... -f deploy/production/docker-compose.yml config --quiet`
- Backend production image build succeeded.
- Frontend production image build succeeded.
- `git diff --check` passed.
- Actual remote deployment was not run because no VPS target/credentials were
  available in this task.

## Follow-ups / Deferred
- Run the deployment against the intended VPS with a real `.env`.
- Verify the public reverse proxy routes the `proxy-tier` network to the
  `maricho-frontend` and websocket endpoint.
- Add a CI job that invokes the deployment preflight against a disposable
  Compose environment if release automation is desired.

## References
- `DevOps_and_Infrastructure/MARITCHO-2026-11-11-production-compose-build-context.md`
- `/home/shadowe/Projects/ProjectFlow/projectflow_backend/deploy.sh`
- `/home/shadowe/Projects/ProjectFlow/projectflow_backend/deploy_upload.sh`
- `deploy/production/deploy.sh`

---

**Completed By:** Copilot
**Duration:** Same engineering session
