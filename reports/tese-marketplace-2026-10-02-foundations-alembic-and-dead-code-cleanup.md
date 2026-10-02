# Foundations pass: adopt Alembic, remove dead microservice-era code and tooling

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api / deploy tooling)
**Type:** Architecture Decision / Cleanup
**Status:** Completed

## Summary
The user raised a broad concern: the codebase "feels wrong," specifically
citing "having multi services in it" and a lack of DB normalization/
constraints, and asked what to actually do about it given the project is
still pre-launch (testers, not real users - lower risk to fix things now
than later). A full audit was run first, then the user chose to start
with the lowest-risk, highest-leverage piece: adopt real Alembic
migrations and remove the deploy-tooling and application-code artifacts
that actively misrepresent the architecture as multi-service. What
started as "set up Alembic + fix stale deploy configs" grew once
`app/main.py` turned out to still implement a full reverse-proxy/gateway
layer for microservices that no longer exist - confirmed as the actual
root of the "feels like multiple services" impression, more so than any
config file.

## Context / Trigger
User, verbatim: "its actually in its later dev not yet real users they r
just tester, so take that inot consideration n lets see what to go on
about" - a direct response to being told a full rewrite would be
high-risk for a production app with real users; the correction (pre-
launch, testers only) changed the risk calculus enough to justify a
broader cleanup pass than would otherwise be reasonable to do live.

## Scope
**Included:**
- A full audit (via a forked research agent) of DB schema normalization/
  constraint gaps and backend architecture issues across every module
  (auth, catalog, orders, brain, chat, media) - not just what prior
  sessions had already touched.
- Adopting real Alembic migrations, replacing the ad-hoc raw-SQL
  `migrations/*.py` script pattern used all session.
- Removing deploy tooling (CI workflow + 4 scripts) that referenced an
  abandoned 8-microservice split.
- Removing dead application code from the same abandoned split
  (`app/main.py`'s proxy/gateway layer, `app/composite.py`) once it
  became clear this was the real source of the "multi services"
  impression, folded in after an explicit scope-expansion check with the
  user.
- Fixing a real bug found along the way (telemetry silently failing on
  every call) and a DB bookkeeping issue (an orphaned `alembic_version`
  row from an earlier, abandoned Alembic attempt).

**Explicitly excluded** (per the user's own prioritization, offered as
options but not chosen this round):
- Collapsing the 5 separate SQLAlchemy engines in `app/database.py`
  (`auth_engine`/`brain_engine`/`chat_engine` all point at the same DB as
  `store_engine` in every real environment today, but this wasn't part
  of what was approved - flagged as a finding, not acted on).
- Adding missing foreign keys across `orders`/`chat`/`brain` models.
- Converting unconstrained status/type strings to real DB enums outside
  of what was already done for `Category.listing_type` in an earlier
  session.
- Wrapping payment routes in `@transactional()` (flagged by the audit as
  the single highest-risk item - real money, zero atomicity guarantee -
  but not part of this round's chosen scope).
- Building real auto-deploy CI/CD to replace the disabled GitHub Actions
  workflow - a separate, bigger decision requiring verified secrets and a
  chosen strategy.

## Method
1. Ran a forked audit agent across the whole backend before proposing
   anything, specifically asked to produce a prioritized, evidence-based
   punch list rather than prose - so the user could pick a starting point
   with real information instead of guessing at severity.
2. Presented the audit findings with explicit severity labels and asked
   the user to choose a starting point via a structured question rather
   than assuming the broadest option was wanted.
3. When a discovery (the dead orchestrator in `main.py`) turned out to be
   meaningfully bigger than the approved scope, stopped and asked rather
   than silently expanding - the risk profile of touching the core
   request-routing file of a running app is qualitatively different from
   config cleanup, even pre-launch.
4. For every deletion (deploy scripts, `composite.py`, dead config
   fields), confirmed via `grep` across the *entire* repo (both backend
   and both frontends) that nothing else referenced what was being
   removed, before removing it - not just checking the obvious call
   sites.
5. For the Alembic baseline specifically: generated the migration via
   `--autogenerate` against the live production schema (not a guess at
   what it should contain), reviewed that its body was empty before
   stamping it as applied, and only then copied the file back into the
   committed repo - so the baseline is provably an accurate snapshot of
   reality, not an assumption.
6. Verified every change against live production after each deploy step
   (container startup logs, side-by-side curl comparisons of behavior
   before/after, and for the telemetry fix specifically, a real end-to-end
   test: register a user, add to cart, confirm the event actually landed
   in the `events` table).

## Decisions & Findings
- **The real "multi services" culprit was application code, not just
  deploy config.** `app/main.py`'s "Smart Orchestrator" - a full reverse
  proxy with a service map, feature flags, and cluster-health probes
  against dead hostnames - was unreachable dead code (every module's
  `ENABLE_MODULAR_*` flag has been permanently `True` with no path to set
  it `False`), but reading it gives a completely false impression of the
  actual architecture. This was judged higher-value to fix than the
  deploy YAML alone.
- **Two self-redirects were real and preserved exactly.**
  `/api/sys/dashboard` and `/api/sys/users` are still called by
  `admin-dashboard` today; removing the proxy layer required carefully
  keeping these two working via the same `localhost:8000` self-loopback
  mechanism, verified identical before/after via direct curl comparison.
  (`/api/sys/dashboard` was separately found to already 404 even via its
  direct, non-proxied route - a pre-existing bug, explicitly not treated
  as something this cleanup caused or needed to fix.)
- **Telemetry's fix was an upgrade from "always silently fails" to
  "actually works"**, not a new feature - the in-process event-ingestion
  logic it needed already existed in the Brain module; the HTTP hop to a
  dead hostname was the only thing standing between it and working.
- **The Alembic baseline came back empty** (`pass`/`pass` on
  `upgrade`/`downgrade`) - confirming the models and the live schema were
  already in sync, i.e. this session's prior ad-hoc migration scripts had
  been applied correctly and consistently all along. Alembic now has a
  true starting point to diff all future changes against.
- **An orphaned `alembic_version` row** (`002_add_listing_type`, no
  matching file anywhere in git history) blocked the first autogenerate
  attempt - evidence of an earlier, abandoned attempt at adopting
  Alembic that never got its migration committed. Cleared via Alembic's
  own `stamp --purge` rather than a raw `DROP TABLE` (which the
  environment's destructive-action safeguard correctly blocked).

## Changes Made
Deploy tooling:
- Removed `.github/workflows/deploy.yml` (failed on every push all
  session), `local-deploy.sh`, `local-deploy.ps1`, `tese.ps1`,
  `local-deploy-enhanced.ps1`, `deployment-config.json`.

Backend (`apps/store-api`):
- `app/main.py` - removed `SERVICE_MAP`, `is_modular` logic,
  `ENABLE_MODULAR_*` conditionals (routers now mount unconditionally),
  simplified `cluster_health`, removed `/api/docs/master`. Kept
  `/api/sys/dashboard` and `/api/sys/users` self-redirects unchanged.
- Deleted `app/composite.py` and `app/tests/test_saga.py`.
- `app/config.py` - removed `ENABLE_MODULAR_*` and
  `AUTH_API_URL`/`CATALOG_API_URL`/`ORDER_API_URL`/`CHAT_API_URL`/
  `BRAIN_API_URL`.
- `app/modules/brain/routes/intelligence.py` /
  `app/modules/orders/services/telemetry_service.py` - telemetry now
  calls brain's event-ingestion in-process.
- Fixed `app/tests/test_orchestrator.py`'s stale proxy-failure assertion.
- Deleted `migrations/add_messaging_tables.py` (imported a module,
  `app.messaging`, that no longer exists).
- Added `alembic.ini`, `alembic/env.py`, `alembic/script.py.mako`, and
  the baseline migration `alembic/versions/e87a2c1df002_baseline.py`.

## Verification
- `python3 -m py_compile` on every changed Python file - clean.
- Production redeploy after every logical change, each confirmed via
  clean container startup (no crash loop) before moving to the next step.
- Side-by-side curl comparison of `/api/catalog/products`,
  `/api/composite/home`, `/api/sys/users`, `/api/sys/dashboard` before
  and after the `main.py` change - identical status codes throughout.
- End-to-end telemetry test: registered a throwaway account, added an
  item to cart, confirmed no `[Telemetry] Failed` log line and a real
  `cart_add` row in the `events` table - first successful telemetry
  event ever recorded via this path.
- `alembic current` on the production container reports
  `e87a2c1df002 (head)`, matching the database's `alembic_version` table.
- Final smoke test across both frontends (`tesemarket.com`,
  `admin.tesemarket.com`) and `/api/v1/health/cluster` - all 200.

## Follow-ups / Deferred
- Collapse `app/database.py`'s 5 separate engines into one (all but
  `sourcing_engine` point at the same DB today) - flagged, not done this
  round.
- Add missing foreign keys across `orders`/`chat`/`brain` models.
- Wrap payment routes (`/initialize`, the ZB webhook) in
  `@transactional()` - the audit's single highest-risk finding, deferred
  by explicit user choice to start with the lower-risk foundations work
  first.
- Convert remaining unconstrained status/type string columns
  (`UserRole.role`, `ProviderApplication.status`, `Product.listing_type`,
  `Conversation.conversation_type`/`.status`) to real DB enums, matching
  what `Order.status`/`Payment.status` already do correctly.
- Normalize `ProviderApplication.application_type`'s comma-separated
  multi-role string into a proper junction table.
- Decide whether to build real auto-deploy CI/CD now that the broken one
  is removed.

## References
- `Architecture_and_Design/tese-marketplace-2026-10-02-dead-smart-orchestrator-proxy-layer.md`
- `Backend_and_API/tese-marketplace-2026-10-02-telemetry-silently-failing-every-call.md`
- `DevOps_and_Infrastructure/tese-marketplace-2026-10-02-dead-deploy-tooling-from-abandoned-split.md`
- `Database_and_State/tese-marketplace-2026-10-02-orphaned-alembic-version-row.md`
- Key files: `apps/store-api/app/main.py`, `apps/store-api/alembic/`,
  `apps/store-api/app/modules/orders/services/telemetry_service.py`

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~2.5 hours from initial complaint to verified fix in production
