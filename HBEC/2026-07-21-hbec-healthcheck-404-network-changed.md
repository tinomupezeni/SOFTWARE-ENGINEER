# Backend Healthcheck 404 (ERR_NETWORK_CHANGED) Bug

**Date:** 2026-07-21
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Immediately following a deployment, both the Admin and Student web frontends started failing with `net::ERR_NETWORK_CHANGED` errors in the browser. 

## Symptoms
- Frontend network requests aborted with `ERR_NETWORK_CHANGED`.
- Checking `docker ps` on the VPS showed that both `hbec-admin-backend` and `hbec-student-backend` containers were marked as `(unhealthy)`.

## Investigation Steps
1. **Container Logs:** Checked the `hbec-admin-backend` container logs, which showed repeated occurrences of:
   `"message": "Not Found: /health/"`
2. **Healthcheck Configuration:**
   - The system was recently updated to use separate probe pathways (`/health/live/` and `/health/ready/`) as per `AGENTS.md` operational rules.
   - However, the `HEALTHCHECK` instructions inside `ADMIN/adminBackend/Dockerfile` and `STUDENT/hbec_backend/Dockerfile` were still attempting to ping the legacy `http://localhost:8000/health/` URL.
   - Additionally, `vps_docker_compose.yml` had hardcoded `test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/')"]` overrides.
3. **Traffic Routing Failure:** Because the Docker `HEALTHCHECK` received 404s, Docker marked the containers as `unhealthy`. The reverse proxy (Gateway/Traefik) correctly refused to route traffic to unhealthy upstream containers, abruptly closing active connections to the frontends and triggering the browser's `ERR_NETWORK_CHANGED` error.

## Resolution
1. Updated `ADMIN/adminBackend/Dockerfile` and `STUDENT/hbec_backend/Dockerfile` to hit `/health/live/`.
2. Updated `STUDENT/Frontend/vps_docker_compose.yml` to hit `/health/live/` in its Python urllib test command.
3. Committed and pushed changes to `master` to trigger a redeployment.

## Prevention
- Standardized healthcheck paths across all configurations.

---

**Resolved By:** Antigravity (AI Principal Engineer)
**Time to Resolution:** 5 minutes
