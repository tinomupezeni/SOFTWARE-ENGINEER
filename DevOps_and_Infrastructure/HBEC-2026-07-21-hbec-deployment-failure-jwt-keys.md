# HBEC VPS Deployment Failure: JWT Keys Volume Mapping Bug

**Date**: 2026-07-21
**Application**: HBEC Student & Admin Backend / Celery Workers
**Environment**: Production (VPS)

## Issue Summary
GitHub Actions continuous deployment to the VPS was failing with a `dependency failed to start` error. `docker compose` flagged `hbec-student-worker` as unhealthy, causing `student-beat` to fail to start. Additionally, both `hbec-student-backend` and `hbec-admin-backend` were crash-looping with the following error:
`IsADirectoryError: [Errno 21] Is a directory: '/run/secrets/jwt_private.pem'`

## Root Cause Analysis
1. **JWT Keys Volume Mapping Bug**: 
   When the `cd.yml` pipeline extracted the updated repository tarball into the VPS deployment directory (`/opt/hbec/`), it did not run a script to dynamically generate the missing `jwt_private.pem` file in the `/opt/hbec/docker/keys/` directory before executing `docker compose up -d`. 
   Because the file was missing on the host system, Docker Compose automatically created empty directories in place of the mapped volumes. The Django backend and Celery workers crashed instantly when attempting to read the expected JWT key file.
2. **Missing Environment Variables**: 
   Strict environment interpolation in newer Docker Compose versions flagged `GRAFANA_ADMIN_PASSWORD` and `LANGFUSE_SECRET` as missing/empty in the generated `/opt/hbec/.env` file. This caused `docker compose up -d` validation to fail after the keys were manually fixed.

## Resolution
1. **Directory Cleanup**: SSH'd into the VPS and removed the empty directories created by Docker Compose in `/opt/hbec/docker/keys/`.
2. **Restored Keys**: Copied the valid keys from the local user backup (`~/projects/HBEC/docker/keys/`) to the deployment directory (`/opt/hbec/docker/keys/`).
3. **Environment Fix**: Appended the missing variables (`GRAFANA_ADMIN_PASSWORD`, `LANGFUSE_SECRET`, and `LANGFUSE_SALT`) to `/opt/hbec/.env`.
4. **Manual Sync & Rebuild**: Deployed the updated `requirements/base.txt` and `docker-compose.production.yml` files manually via `scp`. Rebuilt the `hbec-admin-backend` and `hbec-student-backend` Docker images on the VPS.
5. **Restarted Services**: Successfully restarted the services and workers manually using `docker compose -f docker-compose.production.yml --profile workers up -d --remove-orphans`.
