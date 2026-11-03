# Admin API unreachable through public domain — routes not dual-mounted like every other group

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Production (`agromarketing.co.zw`)
**Severity:** Critical
**Status:** Resolved — fix deployed in commit `1c4f515`, verified live

## Summary
Every admin API call (list unverified buyers, verify a buyer, list all
products as admin, delete any product as admin) returns 404 when called
through the public production domain, because `adminRoutes` is the only
route group in `server.js` not mounted at both `/x` and `/api/x`. The
external reverse proxy in front of the VM strips the `/api` prefix before
forwarding to the backend container; every other route group was
deliberately dual-mounted to survive that, but `adminRoutes` was missed.

## Symptoms
- `GET https://agromarketing.co.zw/api/admin/products` → `404 Route not
  found: GET /admin/products` (note: the error echoes the path with `/api`
  already stripped).
- Same for `/api/admin/buyers/unverified` and the verify/delete admin
  endpoints.
- The admin dashboard frontend (`frontend/src/pages/dashboard/
  AdminDashboard.tsx`) is coded correctly — it uses the shared
  `API_BASE_URL` and the stored Bearer token (see
  [[Market-Link-2026-11-03-admin-buyer-review-url-token-drift]], already
  fixed) — but every request it makes will still 404 in production because
  the backend route itself is unreachable at that path.

## Environment Details
- **Server/Host:** `agromarketing.co.zw`, backend container `marketlink_backend` on `agromarket-vm`
- **Services Affected:** Admin dashboard (buyer verification, product moderation)
- **Related Components:** `backend/server.js`, `backend/routes/adminRoutes.js`
- **Time First Observed:** 2026-11-03, during admin-dashboard QA of release `34274f0`

## Investigation Steps

### 1. Initial Diagnosis
`curl https://agromarketing.co.zw/api/admin/products` returned 404 even
though the route is registered in `server.js` and a check of other
`/api/*` endpoints (e.g. `/api/products`) succeeded.

### 2. Root Cause Analysis
Compared the same request made three ways:

```bash
curl https://agromarketing.co.zw/api/admin/products          # 404, path logged as /admin/products
curl http://10.50.101.17:5001/api/admin/products              # 401 Not authorized (route exists)
curl http://10.50.101.17:5001/admin/products                  # 404 Route not found (no bare mount)
```

Hitting the backend container directly at its exposed port (bypassing the
external reverse proxy entirely) proves the route exists and is correctly
authenticated at `/api/admin/*`. Hitting it through the public domain
strips `/api` before the request reaches the container. Every other route
group in `server.js` (`auth`, `products`, `users`, `chat`, `ussd`) is
mounted twice, once bare and once under `/api`, specifically to survive
this stripping — `adminRoutes` was never given the same treatment.

### 3. Key Findings
- `server.js` mounts `app.use("/api/admin", adminRoutes);` with no matching
  `app.use("/admin", adminRoutes);` line, unlike every sibling route group.
- The external reverse proxy lives outside this VM (no nginx process or
  container was found on `agromarket-vm` itself) and is out of scope to
  change from this side — the existing dual-mount pattern is the
  established workaround for it in this codebase.
- This bug predates release `34274f0`; it was not introduced by Codex's
  fixes and was not covered by Codex's smoke testing, which used the
  non-admin registration/product/email flows only.

## Root Cause
`adminRoutes` was mounted only at `/api/admin`, missing the bare `/admin`
mount that every other route group has specifically to survive the
external proxy's `/api`-prefix stripping.

## Prevention / Rule
**Guardrail:** Add a route-reachability smoke check to release testing that
hits every mounted route group through the actual public domain (not just
the exposed container port), so a route group missing the dual-mount
pattern fails before release instead of silently 404ing in production.

## Solution

### Immediate Fix
Added the missing bare mount in `backend/server.js`:

```js
app.use("/admin", adminRoutes);
app.use("/api/admin", adminRoutes);
```

Committed as `1c4f515` on `main`, pushed to GitHub, transferred to
`agromarket-vm` via `git bundle`/`scp` (the VM has no GitHub credentials),
fast-forwarded both the VM's `main` checkout and the active release
worktree `agromarket-release-34274f0`, rebuilt the `agromarket-backend`
image with `docker compose -p agromarket`, and redeployed
`marketlink_backend`.

### Long-term Fix
Remove the need for dual-mounting altogether by fixing the external
reverse-proxy configuration to forward `/api/*` without stripping the
prefix, or by normalizing the proxy to always strip it and mounting every
backend route group bare only. Either removes this entire class of
mismatch; out of scope for this project's VM access.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Verification

- `npm run test:flows` (local): 7/7 still pass after the change.
- Local server smoke test: both `/admin/products` and `/api/admin/products`
  returned `401 Not authorized` (route reachable, correctly gated) before
  deploying.
- Backend image rebuilt and confirmed clean (no `.env`, no `uploads`, no
  `private-uploads` baked in) before redeploy.
- After redeploy, live checks against `https://agromarketing.co.zw`:
  `/api/admin/products` and `/api/admin/buyers/unverified` both return
  `401 Not authorized` (previously `404`). Homepage and `/api/products`
  unaffected (`200`).
- Zero admin accounts still exist in production and there is still no
  signup/seed path to create one — the live buyer-verify/product-delete
  admin *workflow* itself remains untested pending a decision on creating a
  temporary admin account for that purpose.

## Related Issues
- [[Market-Link-2026-11-03-admin-buyer-review-url-token-drift]] (frontend-side admin fix, already deployed — unaffected by this)
- `SWAP-O-SELL-2026-10-15-messaging-api-route-prefix-mismatch.md` (same class of bug, different project)

## References
- `backend/server.js`
- `backend/routes/adminRoutes.js`

---

**Resolved By:** Claude
**Time to Resolution:** Same session as discovery
