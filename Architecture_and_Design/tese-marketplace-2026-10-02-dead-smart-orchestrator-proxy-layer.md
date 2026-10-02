# app/main.py still implemented a full reverse-proxy layer for microservices that no longer exist

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
`app/main.py` (titled "Smart Orchestrator") implemented a complete reverse-
proxy layer - `universal_proxy`, `forward_request`, a `SERVICE_MAP` of
dead hostnames (`tese-auth-api`, `tese-catalog-api`, `tese-order-api`,
`tese-brain-api`, `tese-chat-api`, `tese-media-api`), plus
`ENABLE_MODULAR_*` feature-flag conditionals around every router mount -
all left over from before auth/catalog/orders/brain/chat were
consolidated into this single app. A parallel file, `app/composite.py`,
made the same kind of dead HTTP calls for a home-page aggregator and a
"checkout saga" with a simulated payment step. Found while investigating
the user's complaint that the codebase "feels like" it has multiple
services in it.

## Symptoms
- Not a user-facing error - the dead code paths were unreachable in
  practice (see Root Cause), so nothing was failing visibly. The symptom
  was architectural: reading `main.py` gives a false impression that
  auth/catalog/orders/brain/chat are still separate deployable services
  behind a gateway, driving the user's "this feels wrong" assessment.
- If `composite.py`'s `/api/composite/checkout` or `/api/composite/home`
  had ever been called, they would have failed outright (connecting to
  hostnames like `tese-catalog-api:8000` that don't resolve in the actual
  Docker network).

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-store-api`
  container)
- **Services Affected:** Request routing for the entire backend
- **Related Components:** `app/main.py`, `app/composite.py`, `app/config.py`
  (`ENABLE_MODULAR_*`, `*_API_URL` settings)
- **Time First Observed:** 2026-10-02, during an architecture audit
  requested by the user

## Investigation Steps

### 1. Initial Diagnosis
User feedback that the codebase "feels like" it has multiple services
prompted a full-backend audit (see the companion report). The audit
flagged `app/database.py`'s five separate SQLAlchemy engines and stale
deploy configs, but reading `main.py` directly surfaced something bigger:
an entire proxy/gateway implementation sitting alongside the real
modular-monolith routers.

### 2. Root Cause Analysis
Traced `ENABLE_MODULAR_AUTH`/`_CATALOG`/`_ORDERS`/`_BRAIN`/`_MEDIA`/`_CHAT`
in `app/config.py` - all default to `True`, and `grep` across the entire
app found nothing that ever sets any of them to `False`. In
`universal_proxy`, every one of the 6 known service names is checked
against `is_modular` before the `SERVICE_MAP` lookup is even reached:
since all 6 are always "modular," the proxy-forwarding branch is
unreachable dead code for every real request. Confirmed `composite.py`
has zero callers in either `customer-store` or `admin-dashboard` via
`grep` across both frontends' source.

### 3. Key Findings
- Two self-redirects inside `universal_proxy`'s `/sys/` handling
  (`/api/sys/dashboard`, `/api/sys/users`) are the only part of this
  machinery actually exercised - confirmed via `grep` that
  `admin-dashboard`'s `userService.ts` still calls `/sys/users/`. These
  forward to `localhost:8000` (the same container, same process), which
  works since it's a self-loopback, not a real cross-service call.
- `/api/sys/dashboard`'s target (`/api/orders/admin/dashboard/stats`) was
  independently confirmed to already 404 even called directly (not via
  the redirect) - a pre-existing, unrelated bug in `admin-dashboard`'s
  dashboard widget, not something this cleanup introduced or should fix
  as part of this change.
- `cluster_health` and the (now-removed) `/api/docs/master` endpoint both
  made real HTTP calls to the same dead hostnames, meaning any ops
  dashboard or tooling built against `/api/v1/health/cluster` would have
  always reported every module "unreachable" except by the
  `ENABLE_MODULAR_*` short-circuit.

## Root Cause
This was a transitional dual-mode implementation (proxy-to-microservice
as the fallback, in-process module as the "new" path) from when
auth/catalog/orders/brain/chat were being consolidated into one app. The
consolidation finished - every module has been `ENABLE_MODULAR_*=True`
with no code path left to ever flip it `False` - but the transitional
scaffolding (the proxy, the service map, the feature flags themselves)
was never removed once it stopped being needed.

## Prevention / Rule
**Guardrail:** A boolean feature flag with no code path that can ever set
it to its non-default value (grep for assignments, not just reads) is
evidence a migration is complete and the flag - and whatever it still
guards - should be removed, not left in place "in case." Treat finishing
a consolidation/migration as including deleting its own scaffolding as
part of done, not a separate future cleanup task.

## Solution

### Immediate Fix
- Removed `SERVICE_MAP`, the `is_modular` computation, and the
  `ENABLE_MODULAR_*` conditionals around router mounting in `app/main.py`
  - all 6 internal routers now mount unconditionally, which is what
    actually happens today in every environment anyway.
- Simplified `cluster_health` to report internal module status directly
  instead of probing dead hostnames; removed `/api/docs/master` entirely
  (no remote OpenAPI specs exist to merge - `/docs` already covers
  everything in-process).
- Kept `/api/sys/dashboard` and `/api/sys/users` self-redirects exactly as
  they behaved before (confirmed via side-by-side curl comparison against
  the direct routes pre- and post-change) - `admin-dashboard` still
  depends on them.
- Deleted `app/composite.py` (zero callers) and its router mount, and
  `app/tests/test_saga.py` (tested only the deleted code).
- Removed `ENABLE_MODULAR_*` and `AUTH_API_URL`/`CATALOG_API_URL`/
  `ORDER_API_URL`/`CHAT_API_URL`/`BRAIN_API_URL` from `app/config.py`
  after confirming zero remaining references anywhere in the app.
- Fixed `app/tests/test_orchestrator.py`'s `test_proxy_catalog_products`,
  which asserted a 502 "catalog-api not running" - already stale before
  this change, since `/api/catalog/products` has been served by the real
  internal catalog router the whole time, not a proxy.

```bash
python3 -m py_compile app/main.py app/config.py   # clean
```
Verified in production: clean container startup (no crash loop), identical
200/404/401 behavior on `/api/catalog/products`, `/api/composite/home`,
`/api/sys/users`, `/api/sys/dashboard` before and after the change;
`/api/v1/health/cluster` now returns immediately without any dead-host
network calls.

### Long-term Fix
None needed beyond this cleanup - the modules are genuinely consolidated
now, with no remaining dual-mode machinery to maintain.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `reports/tese-marketplace-2026-10-02-foundations-alembic-and-dead-code-cleanup.md`
  (the umbrella initiative this was found and fixed under)
- `Backend_and_API/tese-marketplace-2026-10-02-telemetry-silently-failing-every-call.md`
  (same root cause - a dead hostname from the same abandoned split -
  found in a different file)
- `DevOps_and_Infrastructure/tese-marketplace-2026-10-02-dead-deploy-tooling-from-abandoned-split.md`
  (the deploy-config side of the same abandoned microservice split)

## References
- `apps/store-api/app/main.py`
- `apps/store-api/app/composite.py` (deleted)
- `apps/store-api/app/config.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~50 minutes from discovery to verified fix in production
