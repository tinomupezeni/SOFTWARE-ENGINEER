# Backend Docker HEALTHCHECK fails with DisallowedHost in production

**Date:** 2026-11-04
**Project:** LEC Virtual Labs
**Environment:** Production (`hbca-vps`, first deploy of `vlabs-backend-blue`)
**Severity:** Medium (blocked the first production deploy's health gate; no data risk)
**Status:** Resolved

## Summary
The first production deploy of `vlabs-backend-blue` failed `docker compose up --wait`'s
health gate. The container's own `HEALTHCHECK` curls `http://127.0.0.1:8000/api/subjects/`
from inside the container, but production's `ALLOWED_HOSTS` was set to only
`hbca.tech,www.hbca.tech` (correct for real traffic, which always arrives via nginx with
that Host header) — Django's `SecurityMiddleware` rejected the healthcheck's own
`127.0.0.1:8000` Host header as `DisallowedHost`, so gunicorn never returned a response
the healthcheck could see as healthy, and the container was permanently marked unhealthy.

## Symptoms
- `docker compose --profile color-blue up -d --wait` exited with
  `container vlabs-backend-blue is unhealthy`.
- `docker logs vlabs-backend-blue` showed a 500 on every healthcheck hit:
  `django.core.exceptions.DisallowedHost: Invalid HTTP_HOST header: '127.0.0.1:8000'.
  You may need to add '127.0.0.1' to ALLOWED_HOSTS.`

## Environment Details
- **Server/Host:** `hbca-vps`, `/sdb-disk/projects/vlabs`
- **Services Affected:** `vlabs-backend-blue` only (first deploy, before any real traffic)
- **Related Components:** `backend/Dockerfile`'s `HEALTHCHECK`, `backend/config/settings.py`'s
  `ALLOWED_HOSTS` (env-driven)
- **Time First Observed:** 2026-11-04, during `scripts/deploy/deploy-color.sh blue`

## Investigation Steps

### 1. Initial Diagnosis
`docker compose up --wait` reported the container unhealthy with no further detail in its
own output; `docker logs vlabs-backend-blue --tail 80` on the VPS showed the real cause
immediately — a `DisallowedHost` traceback on every healthcheck request.

### 2. Root Cause Analysis
The Dockerfile's `HEALTHCHECK` (added this same session, for this same deploy) hits the
container's loopback address directly — standard practice for a container healthcheck —
but production's `.env` set `ALLOWED_HOSTS` to the real public domain only, with no
`127.0.0.1`/`localhost` entry, since that file was written for the public-facing contract
(`contracts/api.md`), not for the internal healthcheck's own request shape.

### 3. Key Findings
- Real production traffic never carries a `127.0.0.1` Host header — nginx always forwards
  the actual public `Host` (`proxy_set_header Host $host` in `frontend/nginx.conf.template`)
  — so adding `127.0.0.1,localhost` to `ALLOWED_HOSTS` doesn't weaken the real host check.
- This only surfaced because the Dockerfile/healthcheck pairing was new this session; the
  `.env.example` template had no reason to carry this guidance before a Docker healthcheck
  existed at all.

## Root Cause
`ALLOWED_HOSTS` in the production `.env` was set to only the public domain, without
accounting for the container's own internal `HEALTHCHECK` request, which necessarily
originates from `127.0.0.1` inside the container.

## Solution

### Immediate Fix
Updated `ALLOWED_HOSTS` on the VPS (`/sdb-disk/projects/vlabs/backend/.env`) to
`hbca.tech,www.hbca.tech,127.0.0.1,localhost`, then recreated `vlabs-backend-blue` to
pick up the change.

### Long-term Fix
Added a comment to `backend/.env.example` explaining that `127.0.0.1`/`localhost` must
stay in `ALLOWED_HOSTS` alongside the real production domain specifically because of the
container's own healthcheck — so this doesn't get silently dropped as "looks like a dev
leftover" by a future deploy.

## Prevention
- [x] `.env.example` now documents why `127.0.0.1`/`localhost` must stay in production's
      `ALLOWED_HOSTS`
- [ ] Consider a lighter-weight healthcheck that doesn't require passing Django's host
      check at all (e.g. a dedicated `/healthz/` view exempted from `ALLOWED_HOSTS`
      enforcement) if this pattern needs to repeat across more services later

## Related Issues
None — first occurrence, caught before any real traffic was routed to this color.

## References
- `backend/Dockerfile` (the `HEALTHCHECK` instruction)
- `backend/.env.example`
- `intelligent_memory_management/decisions/ADR-004-vps-bluegreen-deployment.md`

---

**Resolved By:** Claude Sonnet 5 (Claude Code session)
**Time to Resolution:** <10 minutes, caught during the first deploy's health gate before cutover.
