# Admin Frontend's Vite Dev Proxy Had No Route (or `ws: true`) for the New Notifications WebSocket — Only nginx (Staging/Prod) Was Actually Wired

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Development (`ADMIN/adminFrontend`, `npm run dev`)
**Severity:** Low
**Status:** Resolved

## Summary
While wiring the admin notification queue's new `useNotificationsSocket`
hook (`GET /api/v1/notifications/ws/admin?token=...`) into
`NotificationQueuePage.tsx`, checked the socket URL construction against
this app's actual base-URL convention (`API_BASE_URL = '/api'`, always
relative — `src/lib/api.ts`) and the nginx routing already live for
staging/production (`ADMIN/adminFrontend/nginx.conf`'s
`/api/v1/notifications/ws` location block, which correctly overrides the
general `/api/v1/notifications` block and sets the WebSocket upgrade
headers). `ADMIN/adminFrontend/vite.config.ts`'s dev-server proxy had a
single catch-all `/api` entry pointed at the admin backend
(`http://127.0.0.1:7002`) with no `ws: true` and, more fundamentally, no
separate entry at all for the notifications microservice — so in local
`npm run dev`, **every** `/api/v1/notifications/*` request (the existing
REST drafts/approve/reject endpoints shipped earlier this session, not
just the new socket) was being misrouted to the admin backend, which has
no such routes, rather than to the separate `NOTIFICATIONS` service.

This is the same class of gap already logged for the student frontend
(`HBEC-2026-09-14-student-frontend-vite-dev-proxy-missing-websocket-upgrade-for-notifications.md`),
found independently while building the admin-side equivalent of the same
feature. Unlike that entry, this one was fixed rather than only flagged —
`vite.config.ts` is squarely inside `ADMIN/adminFrontend`, the directory
this task was scoped to, so applying the fix didn't cross into
NOTIFICATIONS/, nginx, or docker-compose (all explicitly out of scope for
this task).

## Symptoms
Not reproduced against a running local `NOTIFICATIONS` service in this
session (static config read, not a live repro against a running stack).
Expected symptom before the fix: any admin frontend REST call to
`/api/v1/notifications/*` under plain `npm run dev` (bypassing
docker-compose/nginx) would 404 against the admin backend rather than
reach the notifications service, and the new WebSocket would fail to
upgrade — silently, since `useNotificationsSocket` treats any close as
routine and just backs off and retries with no visible error.

## Environment Details
- **Server/Host:** Local dev only (`npm run dev`, Vite 8081)
- **Services Affected:** Admin frontend's entire Notifications feature
  (compose/approve/reject queue, and now the live-push socket) when run
  via bare `npm run dev` rather than the docker-compose/nginx-fronted
  local stack. Docker Desktop dev (the documented local workflow per this
  project's `CLAUDE.md`) is unaffected — it goes through
  `ADMIN/adminFrontend/nginx.conf`, which already routes this correctly.
- **Related Components:** `ADMIN/adminFrontend/vite.config.ts`'s
  `server.proxy`
- **Time First Observed:** 2026-09-14, while implementing
  `useNotificationsSocket.ts` for the admin queue and cross-checking the
  socket URL against every layer it has to pass through (app → dev proxy
  or nginx → backend)

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the app-side socket URL construction is correct in all three
environments: it's built from `window.location` (`protocol`/`host`) plus
the literal `/api/v1/notifications/ws/admin` path, matching the same-origin,
relative-`/api` convention this app already uses everywhere (`API_BASE_URL
= '/api'`, no absolute-URL override, unlike the student frontend's
`VITE_API_URL`). That part doesn't depend on the proxy at all.

### 2. Root Cause Analysis
Read `nginx.conf` and found `/api/v1/notifications` (and the more specific
`/api/v1/notifications/ws`) explicitly routed to a **different** upstream
than the rest of `/api`:
```
set $notifications_backend "notifications:8000";
...
location /api/v1/notifications { proxy_pass http://$notifications_backend; ... }
location /api/v1/notifications/ws { proxy_pass http://$notifications_backend; ...upgrade headers... }
```
Then read `vite.config.ts`'s dev proxy, which had only:
```js
proxy: {
  "/api": { target: "http://127.0.0.1:7002", changeOrigin: true },
  "/media": { target: "http://127.0.0.1:7002", changeOrigin: true },
}
```
`7002` is the admin backend's dev port. Checked `docker-compose.yml` and
found the notifications service on a distinct dev port,
`"${PORT_PREFIX:-70}05:8000"` → `7005`, confirming these are two separate
backends that nginx already knows to split on path, but the Vite dev proxy
did not.

### 3. Key Findings
- This wasn't just a missing `ws: true` (as on the student side) — the
  admin dev proxy had no routing split for `/api/v1/notifications` at all,
  so the *existing* REST notification endpoints (drafts list, approve,
  reject, create) were already being misrouted to the wrong backend under
  bare `npm run dev`, independent of the new WebSocket work.
- `http-proxy-middleware` (which Vite's dev proxy wraps) only forwards a
  WebSocket upgrade for a proxy entry that sets `ws: true` — needed in
  addition to the routing split, for the new `/ws/admin` path specifically.
- Vite matches `server.proxy` entries by object-key order, first match
  wins — so the more specific `/api/v1/notifications` entry must be
  declared before the general `/api` entry, mirroring nginx's own "more
  specific location wins" comment in `nginx.conf`.
- Impact was dev-experience only: the docker-compose/nginx-fronted local
  stack (this project's documented dev workflow, see `CLAUDE.md`'s "Local
  Docker Desktop" section) was never affected.

## Root Cause
`vite.config.ts`'s dev-server proxy was never updated when the
`NOTIFICATIONS` microservice was introduced as a separate backend from the
admin backend — nginx got the path split (and later the WebSocket-specific
override) as part of that and this session's work, but the Vite dev proxy,
a second and independent thing fronting the same `/api` prefix, was never
touched.

## Prevention / Rule
**Guardrail:** Whenever a new backend service is introduced behind an
existing `/api` prefix (or a new WebSocket endpoint is added under one),
grep every proxy config that fronts that prefix — not just nginx — before
calling the routing work done. In this repo that's
`ADMIN/adminFrontend/nginx.conf`, `STUDENT/Frontend/nginx.conf`, **and**
each frontend's own `vite.config.ts` `server.proxy`. There's no automated
check that asserts "this proxy entry routes/upgrades this path" short of
an actual dev-mode connection test, which is more end-to-end tooling than
this class of gap currently warrants — so this stays a code-review
checklist item, same as the student-frontend entry for this concluded.

## Solution

### Immediate Fix
Added a more specific proxy entry ahead of the general `/api` one in
`ADMIN/adminFrontend/vite.config.ts`:
```js
proxy: {
  "/api/v1/notifications": {
    target: "http://127.0.0.1:7005",
    changeOrigin: true,
    ws: true,
  },
  "/api": {
    target: "http://127.0.0.1:7002",
    changeOrigin: true,
  },
  "/media": {
    target: "http://127.0.0.1:7002",
    changeOrigin: true,
  },
},
```
This fixes both problems at once: the existing REST notification calls now
reach the right backend under `npm run dev`, and `ws: true` lets the same
entry proxy the new `/api/v1/notifications/ws/admin` WebSocket upgrade.

### Long-term Fix
None needed beyond the above — this was the long-term fix, not a
stopgap. Worth doing the equivalent check on `STUDENT/Frontend/
vite.config.ts` (flagged, not yet fixed, in the sibling entry referenced
above) since that frontend's dev proxy has the same-shaped gap.

## Prevention
- [x] Configuration changes needed — done, see Immediate Fix
- [ ] Monitoring/alerts to add — n/a, dev-only
- [ ] Documentation to update — worth a one-line note in this project's
      service map or `ADMIN/adminFrontend`'s own docs that the dev proxy
      now special-cases `/api/v1/notifications`, so the next person adding
      a new microservice behind `/api` knows to look here too
- [x] Code changes required — see Immediate Fix above

## Related Issues
- `HBEC-2026-09-14-student-frontend-vite-dev-proxy-missing-websocket-upgrade-for-notifications.md`
  — the same class of gap, found independently on the student frontend's
  dev proxy in the parallel work stream building that side of this
  feature; left unfixed there as out of scope for that task.
- `HBEC-2026-09-14-content-gap-reports-unrouted-in-nginx.md` — the nginx
  side of "a new sub-path under an existing prefix needs its own routing"
  already caught once this session, for a different endpoint.

## References
- `/home/shadowe/.claude/plans/crystalline-petting-quilt.md` — the plan
  this feature was built from
- `ADMIN/adminFrontend/vite.config.ts` — `server.proxy`
- `ADMIN/adminFrontend/nginx.conf` — `/api/v1/notifications` and
  `/api/v1/notifications/ws` location blocks
- `docker-compose.yml` — `notifications` service, `PORT_PREFIX` dev port
  mapping
- `ADMIN/adminFrontend/src/features/notifications/hooks/useNotificationsSocket.ts`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery
