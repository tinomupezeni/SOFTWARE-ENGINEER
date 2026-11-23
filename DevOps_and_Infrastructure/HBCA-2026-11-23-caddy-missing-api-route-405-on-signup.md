# Shared Caddyfile only proxied /webhooks/*, not /api/* — signup returned 405

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps, first real user-facing test)
**Severity:** Critical
**Status:** Resolved

## Summary
The first time a real user tried to create an account on `lms.hbca.tech`, the browser got `405 Method Not Allowed` on what should have been a backend API call. The `lms.hbca.tech` block added to HBEC's shared Caddyfile only proxied `/webhooks/*` to the backend — every other path, including all of `/api/*`, fell through to the catch-all `handle {}` that serves the frontend's static files via nginx. nginx returns 405 for any non-GET/HEAD method against its static-file handler, which is exactly what a `POST /api/auth/register` hit.

## Symptoms
- Browser console: `Failed to load resource: the server responded with a status of 405 ()` while attempting to sign up.
- `curl -X POST https://lms.hbca.tech/api/auth/register` returned `405` instead of a FastAPI response.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** hbca-classroom-frontend (received the misrouted request), hbca-classroom-backend (never saw it)
- **Related Components:** `/opt/hbec/scripts/deploy/render-caddyfile.sh` (shared gateway config, generated — see the project's `docs/deploy/RUNBOOK.md`)
- **Time First Observed:** 2026-11-23, first manual end-user test after the first successful blue/green deploy

## Investigation Steps

### 1. Initial Diagnosis
Checked the frontend's `VITE_API_BASE_URL` convention: it's the bare domain (`https://lms.hbca.tech`), with each API call adding its own `/api/...` prefix (e.g. `${baseURL}/api/auth/refresh`) — confirming frontend and backend share one origin in production, unlike `school.hbca.tech`'s explicit `/api/*` vs. dashboard split on the sibling HBEC project.

### 2. Root Cause Analysis
Read the actual `lms.hbca.tech` block as it existed in the shared Caddyfile (added earlier the same day, for the LiveKit webhook fix): it had `handle /webhooks/* { ... }` and a bare `handle { reverse_proxy frontend }` catch-all — no `/api/*` handle at all.

```bash
curl -s -o /dev/null -w "%{http_code}" https://lms.hbca.tech/api/this-should-404-not-405
# 405 (before fix) -> 404 (after fix, proving it now reaches FastAPI's router)
curl -s -o /dev/null -w "%{http_code}" -X POST https://lms.hbca.tech/api/auth/register
# 422 after fix (FastAPI validation error for a missing body) — confirms real routing, not just absence of the old error
```

### 3. Key Findings
- The earlier LiveKit-webhook Caddy patch (same day) added exactly one handle block (`/webhooks/*`) and didn't carry over the far more fundamental `/api/*` route the whole app actually depends on for every feature.
- `/ws/*` (the realtime classroom WebSocket) had the identical gap and was fixed in the same pass, before it could cause its own live incident.
- nginx's 405-for-non-GET-on-static-handler behavior is standard and correct — the bug was entirely in what Caddy routed to it, not in nginx's own config.

## Root Cause
An incomplete Caddy routing patch: `/webhooks/*` was added for a specific, narrow reason (LiveKit's webhook sender), but the much more basic requirement — routing the frontend's own `/api/*` calls to the backend — was never added at all.

## Prevention / Rule
**Guardrail:** Before considering any new domain/route "wired up" in this shared gateway, curl every distinct path prefix the application actually uses (`/api/*` with a non-GET method, not just `/`) against the live domain and confirm the response comes from the intended backend service, not a same-origin static-file fallback. A GET-only smoke test (as `deploy.yml`'s own smoke-test step and this project's manual verification both did) will not catch a routing gap that only affects POST/PUT/DELETE.

## Solution

### Immediate Fix
Added `handle /api/*` and `handle /ws/*` blocks (routing to the active color's backend container) to both `lms.hbca.tech` and `staging-lms.hbca.tech` in `render-caddyfile.sh`, using the same backup/diff/dry-run-validate/apply discipline as every other change to this shared file. Confirmed HBEC's own domains unaffected before and after.

### Long-term Fix
None further — this closes the gap for every current route prefix the backend serves (`/api`, `/webhooks`, `/ws`).

## Prevention
- [x] Configuration changes needed — Caddy routes added
- [ ] Monitoring/alerts to add — a synthetic POST-based uptime check would have caught this before a real user did
- [x] Documentation to update — `docs/deploy/RUNBOOK.md`
- [ ] Code changes required — none, this was purely a gateway config gap

## Related Issues
- Same-day LiveKit webhook routing fix (the patch that introduced the `lms.hbca.tech` block in the first place).

## References
- `docs/deploy/RUNBOOK.md`, step 5 ("HBEC's render script, patched").

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~15 minutes
