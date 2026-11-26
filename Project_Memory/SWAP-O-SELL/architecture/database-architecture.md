# SWAP-O-SELL — Database Architecture

**Last updated:** 2026-11-26

## Engine
Production: PostgreSQL 16 (isolated Compose service, private network, no
host port). Local/dev: SQLite by default when `DATABASE_URL` is unset
(`dj-database-url` resolves the connection). A `django.contrib.postgres`
dependency pitfall exists for SQLite-only local dev — see
[[sqlite-dev-postgres-driver]] in `implementation/`.

## Key entities (`backend/swapapp/models.py` unless noted)
- **User** — has an integer PK (stable, used for all internal FKs) plus a
  unique indexed `public_id` UUID exposed to the client/API. `is_staff` is
  the authoritative boundary between marketplace clients and internal admin
  staff (not the display `role` field) — see
  `Database_and_State`/`decisions` note under admin separation.
- **Product** (listings) — same integer-PK + `public_id` UUID pattern as
  User. Has `accepts_swaps` flag gating swap-offer eligibility.
- **SwapOffer** (`modules/listings`, migrations `0008_swapoffer`,
  `0009_swapoffer_indexes`) — separate model representing a buyer's
  proposal of one of their own active listings (+ optional cash top-up) for
  a seller's swap-enabled listing. Not merged into `Order`. See
  [[swap-offer-separate-model]] in `decisions/`.
- **Order** — existing single-product transaction model; intentionally
  *not* reused for two-sided swap trades.
- Comments use a generic relation keyed by content type + object id;
  product-scoped lookups resolve the public UUID back to the internal
  integer row at the API boundary.
- Messaging conversations (`modules_messaging` app) are internal-integer-PK
  only; UUIDs are only resolved/exposed for product and user references
  inside conversation payloads (not conversation IDs themselves). App label
  must be `modules_messaging` exactly — a mismatch here previously broke
  swap-offer conversation relations (`Database_and_State/SWAPOSELL-2026-10-15-swap-offer-conversation-app-label.md`).

## Migration conventions
UUID adoption (`backend/swapapp/migrations/0005_public_uuid_ids.py`) used an
**expand-and-adopt** pattern: add a new unique UUID column, backfill
generated values, then switch public routes/serializers/lookups over to it
— without touching or renumbering existing integer primary keys, so
existing FKs (comments, orders, likes, saves, analytics) stayed intact.
Treat this as the template for any future public-identifier change.

## Known drift / gaps
- `makemigrations --check --dry-run` has shown pre-existing index-removal
  drift in `modules_listings` and `swapapp` product/order indexes,
  unrelated to swap-offer work — not yet cleaned up as of 2026-10-15.
- 4 backend tests in `modules.listings` were never updated for the
  `public_id` migration and currently fail on `main` — see
  [[stale-tests-after-uuid-migration]].
