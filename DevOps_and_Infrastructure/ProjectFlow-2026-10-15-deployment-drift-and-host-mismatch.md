# Production deployment drift and hostname mismatch

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The ProjectFlow deployment on `restk-vps` is running from `/home/winstontino/apps/projectflow/docker-compose.yml`, not the checked-in `docker-compose.vps.yml`. The active stack uses locally tagged `projectflow-backend:latest` and `projectflow-frontend:latest` images with development-style settings, while the VPS manifest expects registry images and production settings. The active backend also allows only `projectflow.thuthuka.tech`, although the reverse proxy serves both `projectflow.restksolutions.com` and `projectflow.thuthuka.tech`.

## Symptoms
- `docker compose ls` reports the active ProjectFlow configuration as `docker-compose.yml`.
- `docker-compose.vps.yml` is present but is not the active Compose configuration.
- Requests with `Host: projectflow.restksolutions.com` return HTTP 400 `DisallowedHost`.
- Requests with `Host: projectflow.thuthuka.tech` reach the API successfully.
- Running backend and frontend images have no source commit metadata.

## Environment Details
- **Server/Host:** `restk-vps` (`server1.tesemarket.com`)
- **Services Affected:** ProjectFlow backend, frontend, and reverse-proxy routing
- **Related Components:** `/home/winstontino/apps/projectflow/docker-compose.yml`, `docker-compose.vps.yml`, Caddy configuration
- **Time First Observed:** 2026-10-15 during pre-deployment inspection

## Investigation Steps

### 1. Initial Diagnosis
Inspected the active Docker Compose projects, ProjectFlow container images, deployment files, and host-routed API responses without stopping or modifying services.

### 2. Root Cause Analysis
The running Compose project was created from `docker-compose.yml`, whose backend environment sets `DEBUG=True`, uses local image tags, and sets `ALLOWED_HOSTS=projectflow.thuthuka.tech`. The separate VPS manifest has not been used by the active ProjectFlow Compose project.

```bash
ssh restk-vps 'docker compose ls'
ssh restk-vps 'docker inspect projectflow-backend-1'
ssh restk-vps 'curl -H "Host: projectflow.restksolutions.com" http://127.0.0.1:9005/api/'
```

### 3. Key Findings
- Active Compose file: `/home/winstontino/apps/projectflow/docker-compose.yml`.
- Inactive alternative: `/home/winstontino/apps/projectflow/docker-compose.vps.yml`.
- Backend image: `projectflow-backend:latest`, image ID `sha256:b50e522c087b611e32338b7c4b728cfa6342d762123270c29efbde046682f169`, built 2026-10-14.
- Frontend image: `projectflow-frontend:latest`, image ID `sha256:e8c6707813691896636530a74a84fced5337effe9fd82459ce4cfc34f10ef341`.
- Backend container environment reports `DEBUG=True` and `ALLOWED_HOSTS=projectflow.thuthuka.tech`.
- Caddy routes both `projectflow.restksolutions.com` and `projectflow.thuthuka.tech` to the backend/frontend containers.

## Root Cause
Deployment configuration has diverged: the active production stack and the intended VPS manifest are separate files with materially different image sources and runtime settings, and hostname configuration was not kept consistent with the reverse proxy.

## Prevention / Rule
**Guardrail:** Make deployment use one canonical Compose file and require a CI/deploy preflight that renders that file, records the image digest plus source commit, and probes every configured public hostname with the exact Host header.

This prevents an unused production manifest from masking the actual deployment path and catches `ALLOWED_HOSTS`/proxy hostname drift before traffic is switched.

## Solution

### Immediate Fix
No production changes were applied during the read-only inspection.

### Long-term Fix
- Select and document one canonical production Compose file.
- Build immutable, commit-tagged images rather than relying on `latest`.
- Align `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, frontend URLs, and Caddy routes.
- Add a deploy preflight and post-deploy smoke test for both public hostnames.
- Preserve the current image digests and database volume as rollback references before replacement.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-production-config-hardening.md`

## References
- `/home/winstontino/apps/projectflow/docker-compose.yml`
- `/home/winstontino/apps/projectflow/docker-compose.vps.yml`
- Caddy ProjectFlow route on `restk-vps`

---

**Resolved By:** Unassigned
**Time to Resolution:** Ongoing
