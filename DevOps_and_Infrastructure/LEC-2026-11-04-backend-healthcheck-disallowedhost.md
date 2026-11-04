# Backend Docker HEALTHCHECK fails in production (two compounding causes)

**Date:** 2026-11-04
**Project:** LEC Virtual Labs
**Environment:** Production (`hbca-vps`, first deploy of `vlabs-backend-blue`)
**Severity:** Medium (blocked the first production deploy's health gate; no data risk)
**Status:** Resolved

## Summary
The first production deploy of `vlabs-backend-blue` failed `docker compose up --wait`'s
health gate, twice in a row, from two separate causes hit one after the other in the same
debugging pass — both are instances of the same root problem: a container healthcheck
written against local-dev assumptions, run against production's hardened settings for the
first time.

1. The container's own `HEALTHCHECK` curls `http://127.0.0.1:8000/api/subjects/` from
   inside the container, but production's `ALLOWED_HOSTS` was set to only
   `hbca.tech,www.hbca.tech` (correct for real traffic, which always arrives via nginx with
   that Host header) — Django's `SecurityMiddleware` rejected the healthcheck's own
   `127.0.0.1:8000` Host header as `DisallowedHost`.
2. After fixing (1), the same healthcheck still failed: `SECURE_SSL_REDIRECT` is on
   whenever `DEBUG` is off (ADR-003 hardening), so the healthcheck's plain-HTTP loopback
   request got a `301` on every call — proof gunicorn was up, but not proof the view logic
   actually worked, and not one of the status codes the healthcheck accepted.

## Symptoms
- `docker compose --profile color-blue up -d --wait` exited with
  `container vlabs-backend-blue is unhealthy`.
- Cause 1: `docker logs vlabs-backend-blue` showed a 500 on every healthcheck hit:
  `django.core.exceptions.DisallowedHost: Invalid HTTP_HOST header: '127.0.0.1:8000'.
  You may need to add '127.0.0.1' to ALLOWED_HOSTS.`
- Cause 2 (after fixing cause 1): still unhealthy, no error in the app logs this time —
  `docker inspect`'s health log showed `ExitCode: 1` with empty output; running the exact
  healthcheck command manually (`docker exec ... curl -s -o /dev/null -w '%{http_code}'
  http://127.0.0.1:8000/api/subjects/`) returned `301`, not `200`/`401`.

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
- `SECURE_SSL_REDIRECT`'s on-when-`DEBUG`-is-off default is correct, intended hardening
  (ADR-003) — the healthcheck was the thing missing context, not the app. Real requests
  always carry `X-Forwarded-Proto: https` (set by nginx, trusted via
  `SECURE_PROXY_SSL_HEADER`), which a raw loopback curl never does.
- Both causes only surfaced because the Dockerfile/healthcheck pairing was new this
  session; neither existed in local dev (`DEBUG=True` there skips both checks entirely),
  so this was the first time either setting was ever exercised in combination with a
  healthcheck.

## Root Cause
Two production-only settings the healthcheck didn't account for, because it was written
and implicitly tested against local-dev's `DEBUG=True` assumptions: (1) `ALLOWED_HOSTS`
scoped to the public domain only, and (2) `SECURE_SSL_REDIRECT` forcing a 301 on any
plain-HTTP request, including the healthcheck's own loopback one.

## Solution

### Immediate Fix
1. Updated `ALLOWED_HOSTS` on the VPS (`/sdb-disk/projects/vlabs/backend/.env`) to
   `hbca.tech,www.hbca.tech,127.0.0.1,localhost`.
2. Added `-H 'X-Forwarded-Proto: https'` to the healthcheck's `curl` call in
   `backend/Dockerfile`, so it's treated as HTTPS the same way a real proxied request is,
   and actually exercises the view instead of just confirming a redirect.
3. Recreated `vlabs-backend-blue` with the rebuilt image.

### Long-term Fix
Added a comment to `backend/.env.example` explaining why `127.0.0.1`/`localhost` must stay
in production's `ALLOWED_HOSTS`. The `X-Forwarded-Proto` header fix lives directly in the
Dockerfile, next to the healthcheck it corrects.

## Prevention
- [x] `.env.example` now documents why `127.0.0.1`/`localhost` must stay in production's
      `ALLOWED_HOSTS`
- [x] Dockerfile healthcheck now sends `X-Forwarded-Proto: https`, matching how nginx
      actually proxies real requests
- [ ] Consider a lighter-weight healthcheck that doesn't require passing Django's host/SSL
      checks at all (e.g. a dedicated `/healthz/` view exempted from both) if this pattern
      needs to repeat across more services later

## Related Issues
None — first occurrence, caught before any real traffic was routed to this color.

## References
- `backend/Dockerfile` (the `HEALTHCHECK` instruction)
- `backend/.env.example`
- `intelligent_memory_management/decisions/ADR-004-vps-bluegreen-deployment.md`

---

**Resolved By:** Claude Sonnet 5 (Claude Code session)
**Time to Resolution:** <10 minutes, caught during the first deploy's health gate before cutover.
