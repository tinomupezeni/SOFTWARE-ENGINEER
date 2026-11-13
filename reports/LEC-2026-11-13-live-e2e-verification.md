# LEC Biotec Live E2E Verification

**Date:** 2026-11-13
**Project:** LEC Biotec
**Type:** Production Verification / E2E Audit
**Status:** Completed

## Summary
Ran an authenticated browser journey against the deployed LEC Biotec
production stack, covering customer authentication, catalogue browsing, cart
mutation, checkout pricing, order placement, customer order history, admin
authentication, product visibility, order list visibility, and order detail
visibility. The first run exposed missing commerce reference data; the
idempotent commerce seed was applied, after which the complete journey passed.
Temporary accounts and catalogue data were cleaned up without leaving stock
reservations.

## Context / Trigger
The deployment had already passed infrastructure, public smoke, asset, and
anonymous-browser checks, but authenticated customer checkout and staff
operations had not been proven. The production catalogue was empty, so a
temporary test customer, editor, product, SKU, address, and inventory quantity
were authorized for one live test cycle.

## Scope
Included:
- Live production browser journeys at `https://lecbiotec.com`.
- Customer sign-in, product page, cart, checkout, order placement, and order
  history.
- Admin sign-in, product list visibility, order list visibility, and order
  detail visibility.
- Database-backed stock reservation and cleanup verification.
- Public health and migration checks after cleanup.

Excluded:
- Real payment capture. Production is configured with `PAYNOW_MODE=test`, but
  the journey stopped at the pending-payment order state.
- Destructive deletion of order records. Orders are immutable business
  records; temporary orders were cancelled through the lifecycle service and
  retained for audit integrity.

## Method
Provisioned uniquely named temporary identities and catalogue data through the
supported Django services on the VPS. Exercised the deployed storefront and
admin bundles with Playwright using real HTTP, session cookies, database
queries, and browser accessibility locators. Corrected missing production
commerce reference data with the repository's idempotent `seed_commerce`
command, reran the journey, then cancelled orders and deactivated/soft-deleted
temporary records through their domain services.

## Decisions & Findings
- The deployed artifact remained commit `3ff367d`; API, worker, and beat
  identity propagation was consistent.
- The first checkout attempt correctly blocked placement because production
  had no active delivery methods. Six delivery methods and three tax rates were
  seeded without `--force`; this is required production configuration, not test
  data.
- The successful journey created pending-payment orders and verified their
  visibility from both customer and admin surfaces.
- Cleanup through `orders.services.transition` released all held stock. The
  final temporary SKU reported zero reservation, the product was not live, and
  both temporary accounts were inactive.
- Two issue logs capture the setup and production-data gaps:
  `LEC-2026-11-13-e2e-provisioning-assumed-sku-stock.md` and
  `LEC-2026-11-13-production-commerce-seed-missing.md`.

## Changes Made
- Application deployment already running at `3ff367d`.
- Production commerce reference data seeded with:
  `python manage.py seed_commerce`.
- Temporary test product and SKU soft-deleted/deactivated.
- Temporary editor and customer accounts deactivated.
- Three temporary pending-payment orders cancelled through the order lifecycle.
- Issue logs pushed in commits `2b70eee`, `da07dd0`, and `08afe5f`.

## Verification
- Customer sign-in: PASS.
- Catalogue → cart → checkout: PASS.
- Delivery option and quote: PASS after commerce seed.
- Order placement and order number: PASS.
- Customer order history: PASS.
- Admin sign-in: PASS.
- Admin product visibility: PASS.
- Admin order list: PASS.
- Admin order detail: PASS.
- Cleanup: PASS; three orders cancelled, stock reservation `0`, product not
  live, SKU inactive, both accounts inactive.
- Shallow health: PASS, `{"status":"alive"}`.
- Deep health: PASS; database, cache, and storage up, version `3ff367d`.
- Migrations: PASS; no unapplied migrations.

## Follow-ups / Deferred
- Add commerce seed/readiness assertions to the deployment gate so schema
  health cannot appear green while checkout reference data is absent.
- Add a reusable checked-in E2E provisioning fixture or management command that
  uses returned generated slugs and inventory services.
- Retain the cancelled test orders as audit-preserving records; remove only
  through an explicitly approved data-retention procedure if required later.
- Payment capture and webhook/poll reconciliation remain unverified in this
  cycle.

## References
- `deploy.sh`
- `docker-compose.yml`
- `apps/api/apps/orders/management/commands/seed_commerce.py`
- `apps/api/apps/inventory/services.py`
- `apps/api/apps/orders/services.py`
- `Backend_and_API/LEC-2026-11-13-e2e-provisioning-assumed-sku-stock.md`
- `Database_and_State/LEC-2026-11-13-production-commerce-seed-missing.md`

---

**Completed By:** Copilot
**Duration:** One live verification session
