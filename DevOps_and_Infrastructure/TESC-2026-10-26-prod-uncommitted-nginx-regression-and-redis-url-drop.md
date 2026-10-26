# tesc-prod Had Uncommitted Local Fixes/Regressions Never Pushed to Git

**Date:** 2026-10-26
**Project:** TESC
**Severity:** High (a live cache-backend misconfiguration one container
recreate away from breaking OTP login/export verification; a reverted
stale-IP nginx guard one recreate away from repeating a past documented
incident)
**Status:** Fixed (TESC `main` branch commit `e4fbf03`)

## Symptoms / Discovery Context

While preparing to set up blue-green deployment on `tesc-prod`
(`10.50.200.35`), inspected the real running state via SSH before building
anything on top of assumptions from the repo. `git status`/`git diff` on the
VM's checkout (`/home/user/Documents/TESC-main`, branch `main`) showed
uncommitted local edits to `docker-compose.yml` and `nginx/nginx.conf` that
had never been pushed back to GitHub.

## Root Cause

Two independent, unrelated changes had been made directly on the live
checkout at some point and never committed:

1. **Good, undocumented fixes** to `docker-compose.yml`: images pinned to
   the actual running short SHA (`fcf6985`) instead of `:latest`, and the
   `./backend:/app` bind-mount removed (this is the exact
   image-gets-silently-shadowed-by-host-code bug already documented in
   `project_docs/04-infrastructure-and-cicd.md`). But this edit also
   **dropped `REDIS_URL=redis://redis:6379/1`** from the `backend` service's
   `environment:` block (it was present before the edit). Confirmed via
   `docker exec tesc-main-backend-1 env` that the **currently running**
   container still has `REDIS_URL` set — because it hasn't been recreated
   since before this edit. The file on disk would not set it on the next
   recreation. Django's `CACHES` setting
   (`backend/core/settings.py:170`) falls back to
   `redis://localhost:6379/1` when `REDIS_URL` is unset, which inside the
   `backend` container's own network namespace has nothing listening — every
   `django.core.cache.cache.get/set` call would start raising connection
   errors. `cache` is used in `instauth/views/auth_views.py`,
   `academic/services/student_services.py`, `users/otp.py`,
   `users/admin_views.py`, `reports/api.py` (the report-export OTP gate),
   and `reports/pdf_generator.py` — i.e. OTP-based login/export verification
   specifically would have broken the moment `backend` was next recreated,
   with no deploy-time error to flag it.
2. **A regression** to `nginx/nginx.conf`: the `resolver 127.0.0.11
   valid=10s;` + `set $upstream_*; proxy_pass $upstream_*;` pattern (added
   specifically to prevent nginx caching a stale upstream IP forever after a
   container recreate — see the file's own comment, and the documented
   2026-10-12 incident where this exact gap swapped the main/admin and
   institution frontends on tesc-staging) had been **stripped back out**,
   reverting to bare `proxy_pass http://service:port`. The file also still
   referenced the old service names `frontend_client`/`frontend_admin`,
   which don't even match the real running container names
   (`frontend-client-v2`/`frontend-admin-v2`).

Both edits being uncommitted meant git did not reflect what was actually
running, and the regression could recur on the very first future deploy
that recreated `backend`/`frontend-client-v2`/`frontend-admin-v2`.

## Fix

Rewrote both files on `tesc-prod` directly (where the true live state was),
keeping the two good fixes, restoring `REDIS_URL` on `backend`, and
restoring the resolver/stale-IP guard in `nginx.conf` updated to the real
service names. Validated with `nginx -t` inside the live nginx container,
reloaded it live, and confirmed both public domains (`tesc.zchpc.ac.zw`,
`tesc-inst.zchpc.ac.zw`) and `/api/` still responded correctly post-reload.
Committed and pushed from the VM's own checkout as commit `e4fbf03`, then
merged into `staging` locally so both branches have it.

## Verification
- `docker exec tesc-main-nginx-1 nginx -t` — syntax OK, both times (before
  and after the fix).
- `curl -H "Host: tesc.zchpc.ac.zw" http://localhost/` → 200
- `curl -H "Host: tesc-inst.zchpc.ac.zw" http://localhost/` → 200
- `curl -H "Host: tesc.zchpc.ac.zw" http://localhost/api/` → 404 (correct —
  routing works, no view at that exact bare path)
- `git push origin main` succeeded; `git fetch`/merge into local `staging`
  checkout confirmed clean.

## References
- `project_docs/04-infrastructure-and-cicd.md` — documents the bind-mount
  image-shadowing bug this already-applied fix addresses.
- `reports/TESC-2026-10-26-blue-green-production-deployment-guide.md` — the
  blue-green work this discovery was made in service of.
- TESC commit `e4fbf03` (branch `main`).

---

**Found By:** Claude Sonnet 5 (session with tinomupezeni)
