# Student Frontend's Vite Dev Proxy Has No `ws: true` for the New Notifications WebSocket — Only nginx (Staging/Prod) Is Actually Wired

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Development (`STUDENT/Frontend`, `npm run dev`)
**Severity:** Low
**Status:** Identified, Not Fixed — out of scope for the change that surfaced it; local dev is unaffected by the 30s poll fallback

## Summary
While wiring the student notification bell's new `useNotificationsSocket`
hook (`GET /api/v1/notifications/ws?token=...`) into `useNotifications.ts`,
confirmed the socket URL construction against this app's existing base-URL
convention and the nginx routing added for staging/production
(`STUDENT/Frontend/nginx.conf`'s `/api/v1/notifications/ws` location block,
already live). nginx is correctly wired with `proxy_set_header Upgrade
$http_upgrade` / `Connection "upgrade"`. `STUDENT/Frontend/vite.config.ts`'s
dev-server proxy for `/api` (used by `npm run dev`, port 5173 → target
`http://localhost:8000`) has no `ws: true` on that proxy entry and no
separate entry for the `/ws` sub-path, so a developer running the student
frontend locally against a local `NOTIFICATIONS` service would have the
WebSocket connection attempt fail to upgrade — silently, from the app's
point of view, because `useNotificationsSocket` treats any close as
ordinary and just backs off and retries forever.

## Symptoms
None observed directly (not reproduced against a running local
`NOTIFICATIONS` service in this session) — this is a static config read,
not a live repro. The expected symptom: in dev, the bell's socket never
reaches `onopen`, closes/errors immediately, and the hook retries with
exponential backoff up to the 30s cap indefinitely, while the existing
30s poll silently keeps the bell correct — so a developer would see no
error banner, just a bell that never gets faster-than-30s updates locally,
which is easy to mistake for "the feature isn't built" rather than "the
dev proxy doesn't upgrade this path."

## Environment Details
- **Server/Host:** Local dev only (`npm run dev`, Vite 5173)
- **Services Affected:** Student Frontend's notification bell live-push
  path only; the existing 30s poll is unaffected and keeps the bell correct
- **Related Components:** `STUDENT/Frontend/vite.config.ts`'s
  `server.proxy['/api']` entry
- **Time First Observed:** 2026-09-14, while implementing
  `useNotificationsSocket.ts` and cross-checking it against every layer the
  socket URL has to pass through (app → dev proxy or nginx → backend)

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the app-side socket URL construction (`useNotificationsSocket.ts`)
resolves to the same origin + path REST already uses
(`API_BASE_URL` + `/v1/notifications/ws`, scheme swapped `http`→`ws`,
`https`→`wss` from `location.protocol`), matching exactly what
`apiFetch` does for every other endpoint. That part is correct in all three
environments (dev, staging, prod) since it only depends on `API_BASE_URL`
and `location`, neither of which differs by environment.

### 2. Root Cause Analysis
Read `vite.config.ts`'s `server.proxy` block:
```js
proxy: {
  "/api": {
    target: "http://localhost:8000",
    changeOrigin: true,
  },
  ...
}
```
`http-proxy-middleware` (which Vite's dev proxy wraps) only forwards a
WebSocket upgrade request for a given proxy entry when that entry sets
`ws: true` — without it, an upgrade request matching `/api/*` is not
proxied as a WebSocket at all. Compared against `STUDENT/Frontend/
nginx.conf`, which — per this session's plan — got a dedicated, more
specific `/api/v1/notifications/ws` location block with the upgrade headers
nginx needs (`Upgrade $http_upgrade`, `Connection "upgrade"`, a 3600s
`proxy_read_timeout`). Nothing equivalent exists for the Vite dev proxy;
the backend and nginx-routing work this session ("already built and
tested," per the task) never touched `vite.config.ts`, and it was outside
this session's explicit scope (student-frontend hook + tests only) to add
it.

### 3. Key Findings
- Dev and staging/prod have now drifted for this one path: nginx knows how
  to upgrade `/api/v1/notifications/ws`, the Vite dev proxy does not.
- The failure mode is silent by design of the hook being built this
  session: `useNotificationsSocket` treats a close from a failed upgrade
  identically to a legitimate server-side close (including the expected
  `4401` auth-failure case) and just backs off and retries — which is
  correct behavior for real auth/network failures, but means a broken dev
  proxy produces no visible error, just a bell that never updates faster
  than the 30s poll locally.
- Impact is capped by design: the 30s poll (`POLL_INTERVAL_MS` in
  `useNotifications.ts`) is untouched and remains the correctness fallback,
  so this is a dev-experience/observability gap, not a functional break in
  any environment that matters (staging/production both route correctly).

## Root Cause
`vite.config.ts`'s dev-server proxy configuration was not updated when the
`/api/v1/notifications/ws` WebSocket endpoint was added this session — the
work was scoped to the backend, nginx (staging/prod), and the frontend
hook/tests, and no one location owns "does every environment that proxies
`/api` still upgrade this new sub-path."

## Prevention / Rule
**Guardrail:** Whenever a new WebSocket (or any upgrade-requiring) endpoint
is added under an existing REST prefix, grep every proxy config that
fronts that prefix — not just nginx — before calling the routing work
done. In this repo that means `STUDENT/Frontend/nginx.conf`,
`ADMIN/adminFrontend/nginx.conf`, **and** `STUDENT/Frontend/vite.config.ts`'s
`server.proxy` (Admin frontend's dev proxy, if any, should get the same
check). A short-lived checklist item is weaker than a config check, but
there is no automated way to assert "this proxy entry upgrades this path"
short of an actual dev-mode WS connection test, which is more end-to-end
tooling than this gap currently warrants.

This closes the gap because the actual failure wasn't in the new endpoint
or the new frontend hook — both are correct — it was that "wire up the
proxy" was treated as done once nginx was, without checking the dev proxy
is a second, independent thing fronting the same prefix.

## Solution

### Immediate Fix
None applied — left as identified. Fixing `vite.config.ts` was out of
scope for the task this was found under (student-frontend hook + tests
only); flagging here per this repo's standing rule to log every
misconfiguration found, fixed or not.

### Long-term Fix
Add a `ws: true` proxy entry for `/api/v1/notifications/ws` (and
`/api/v1/notifications/ws/admin` on the admin frontend's own dev config, if
it has an equivalent local proxy) in `vite.config.ts`, e.g.:
```js
proxy: {
  "/api/v1/notifications/ws": {
    target: "ws://localhost:8000", // or wherever NOTIFICATIONS runs locally
    ws: true,
    changeOrigin: true,
  },
  "/api": {
    target: "http://localhost:8000",
    changeOrigin: true,
  },
}
```
(more specific entry first, matching the same "longer prefix wins"
reasoning already applied in `nginx.conf`) — and confirm the
`NOTIFICATIONS` service's actual local dev port/target before applying.

## Prevention
- [ ] Configuration changes needed — `vite.config.ts` dev proxy `ws: true`
      entry, not yet applied
- [ ] Monitoring/alerts to add — n/a, dev-only
- [ ] Documentation to update — worth a one-line note in `STUDENT/
      Frontend`'s README or `CLAUDE.md` service map that live notification
      push is nginx-only locally until this is added
- [ ] Code changes required — see Long-term Fix above

## Related Issues
- None yet filed for the backend/nginx portion of this feature (built and
  tested by a separate work stream this session, per the
  `crystalline-petting-quilt` plan's Backend and Deployment sections).

## References
- `/home/shadowe/.claude/plans/crystalline-petting-quilt.md` — the plan
  this feature was built from
- `STUDENT/Frontend/vite.config.ts` — `server.proxy`
- `STUDENT/Frontend/nginx.conf` — `/api/v1/notifications/ws` location block
- `STUDENT/Frontend/src/features/notifications/hooks/useNotificationsSocket.ts`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** N/A — not fixed, documented only
