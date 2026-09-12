# Every Backend Redeploy Breaks the Site Until nginx Is Also Restarted

**Date:** 2026-09-11
**Project:** CRM Professional
**Environment:** Production (restk-vps)
**Severity:** High (full API outage after every backend deploy, until now unnoticed)
**Status:** Resolved

## Summary
After rebuilding and recreating the `backend`/`celery-worker`/`celery-beat` containers (to ship the sale-creation and quotations bug fixes from today), the site's static assets loaded fine but every single API call — including `/health/` — returned `502 Bad Gateway`.

## Symptoms
- `curl https://crm.restksolutions.co.zw/health/` → `502`.
- `docker logs crm-nginx-1`: `connect() failed (111: Connection refused) while connecting to upstream, ... upstream: "http://10.0.3.8:8000/health/"`.
- `docker compose ps` showed `backend` as `healthy` and reachable from inside its own container — the backend itself was fine.

## Root Cause
`nginx`'s `proxy_pass http://backend:8000` resolves the `backend` hostname to a Docker-network IP **once**, when nginx starts (or on its first connection), and does not use a dynamic resolver to notice when that IP changes. Recreating the `backend` container (as any `docker compose up -d backend` rebuild does) gives it a **new** internal IP. nginx kept trying the old, now-dead IP (`10.0.3.8`) until it was itself restarted, which forces it to re-resolve.

This means **every backend deploy on this VPS silently breaks the whole API** until someone thinks to also restart nginx — something `deploy.sh` in the repo does not account for (it doesn't run on this VPS's actual setup at all — see the earlier CI/CD drift entry — so it was never actually protecting against this).

## Prevention / Rule
**Guardrail:** the `resolver 127.0.0.11 valid=10s;` + variable-based `proxy_pass` fix applied below, as a required template/lint rule for every project's nginx config on this VPS — not just this one — since a bare `proxy_pass http://<service>:<port>;` with no resolver is exactly what caches an upstream IP forever across container recreates.

This is guide 10's gateway-unreachable triage checklist item 7 — this incident is that item's origin case.

## Solution (this deploy)
`docker compose -f docker-compose.yml restart nginx` immediately after the backend swap. Confirmed fixed: `/health/` → 200, `/api/v1/contacts/` and `/api/v1/sales/` → 401 (correctly reachable, just unauthenticated), migration state clean.

## Solution (permanent fix)
Removed the static `upstream backend { server backend:8000; }` block from `nginx/nginx.conf` entirely. Added `resolver 127.0.0.11 valid=10s;` (Docker's embedded DNS) to the `server` block, and changed every `proxy_pass http://backend;` (in `/health/`, `/api/`, `/admin/`) to route through a `set $backend_upstream backend:8000; proxy_pass http://$backend_upstream;` pair — using a variable in `proxy_pass` is what actually forces nginx to re-resolve through `resolver` on each request instead of caching the IP once.

Verified on `restk-vps`: rebuilt and deployed the new nginx image, then force-recreated the `backend` container (guaranteed new IP) and hit `/health/` and `/api/v1/contacts/` immediately after — both responded correctly on the very first request, no nginx restart needed. Committed as `e00c76f`.

## Prevention
- [x] Fixed at the config level — dynamic resolver + variable-based `proxy_pass`, verified against an actual backend recreate.
- [ ] Once `deploy.sh` is reconciled with the real `~/apps/crm` setup (see `2026-09-11-cicd-deploy-drift-ghcr-vs-dockerhub.md`), it no longer strictly needs to restart nginx after a backend deploy, but doing so anyway as a matter of habit costs nothing.
- [ ] Given this has presumably happened on every prior backend deploy too (this isn't new today), it's worth asking whether past "random API downtime" reports were actually this. Worth doing the same audit (any other nginx `upstream`/bare-hostname `proxy_pass` blocks) on other projects on this same VPS that share the pattern.

---

**Resolved By:** Claude Code
**Time to Resolution:** ~5 minutes to catch (site verification was part of the deploy step) + ~20 minutes for the permanent config fix, built, deployed, and proven against a live backend recreate the same session.
