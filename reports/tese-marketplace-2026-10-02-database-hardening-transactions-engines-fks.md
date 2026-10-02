# Database hardening pass: payment transactions, engine consolidation, missing foreign keys

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Type:** Architecture Decision / Hardening
**Status:** Completed

## Summary
Continuation of the same-day foundations work - the user asked to pick
up the items explicitly deferred from the first pass ("lets do those not
done things"). Worked through them in risk/value order: wrapped payment
routes in `@transactional()` (the single highest-risk item from the
original audit - real money with no commit at all), collapsed the 3
redundant SQLAlchemy engines left over from the pre-monolith split into
one, and added 14 missing foreign key constraints across orders/catalog/
chat/brain - finding and fixing a real data-integrity bug (9 orphaned
cart rows) along the way. Did not attempt the two remaining, more
invasive deferred items (converting status/type strings to real DB
enums, normalizing `ProviderApplication.application_type`'s comma-
separated roles into a junction table) or the CI/CD strategy decision in
this pass.

## Context / Trigger
User, verbatim: "lets do those not done things" - a direct follow-up to
the prior report's "Follow-ups / Deferred" list.

## Scope
**Included:**
- `@transactional()` on `POST /api/payments/initialize` and
  `POST /api/payments/webhook/zb`.
- Collapsing `auth_engine`/`brain_engine`/`chat_engine` in
  `app/database.py` into aliases of `get_db`.
- Adding foreign key constraints for every cross-table reference that
  was missing one, across `orders`, `catalog`, `chat`, and `brain`
  models, via a real Alembic migration.
- Deleting 9 orphaned `carts` rows found while checking for FK-blocking
  data, per explicit user confirmation.

**Explicitly excluded** (remain on the deferred list):
- Converting `UserRole.role`, `ProviderApplication.status`,
  `Product.listing_type`, `Conversation.conversation_type`/`.status`
  from plain strings to real Postgres enums.
- Normalizing `ProviderApplication.application_type`'s comma-separated
  multi-role string into a junction table.
- Deciding on real auto-deploy CI/CD.

## Method
Worked in strict risk/value order rather than file order: payments
first (explicitly the audit's highest-risk finding), then engine
consolidation (quick, and directly reduces the architectural confusion
from the first pass), then foreign keys last since they required the
most care (checking every candidate column for orphaned data before
constraining it, rather than assuming production data was clean).

For the FK work specifically: ran an orphan check
(`LEFT JOIN ... WHERE ... IS NULL`) against every single candidate
column before writing any model change, so the scope of "which columns
can be safely constrained today vs. need data cleanup first" was known
upfront rather than discovered mid-migration. Where a destructive action
was needed (deleting the 9 orphaned carts), stopped and asked rather
than finding a workaround for the sandbox's safeguard - it had correctly
identified a real risk (irreversible data loss) that warranted explicit
confirmation regardless of the pre-launch context.

For both schema changes (foreign keys), used the newly-adopted Alembic
setup for real this time: generated via `--autogenerate` against the
live schema, reviewed the generated DDL before running it, applied with
`alembic upgrade head` (not `stamp`, since this time the constraints
genuinely didn't exist yet), then copied the migration file back into
the committed repo and rebuilt the image so it persists.

Verified every change end-to-end against live production rather than
just confirming clean startup: a full register → login → cart → address
→ order → payment-initialize → webhook flow for the payment fix (first
time this flow has ever completed and persisted), and a role-grant →
product-create flow for the engine consolidation (confirming the
dual-session route still resolves correctly as one shared session).

## Decisions & Findings
- **Payments had never actually persisted anything.** Confirmed via code
  reading (no `commit()` anywhere in the call chain) before relying on
  the empty `payments`/`orders` tables as supporting evidence - the
  empty tables alone couldn't distinguish "broken" from "pre-launch,
  unexercised," but the code reading made it unambiguous.
- **The 5-engine setup wasn't just redundant - it was a live structural
  trap.** `catalog.py`'s `create_product` already depended on two
  separate sessions (`get_db` and `get_auth_db`) in the same request;
  `@transactional()` only ever managed one of them. Nothing had broken
  yet only because `auth_db` happened to be read-only in that specific
  route - the moment someone added a write through it, it would silently
  never commit, the same bug as payments, waiting to happen again.
- **`ON DELETE` policy was chosen per column's actual role**, not
  applied uniformly: `CASCADE` for ephemeral/personal data (carts,
  addresses, cart items) and derived analytics aggregates (the 4 Brain
  tables); no action (block deletion) for historical/financial records
  (orders, order items, products, conversations, messages); `SET NULL`
  for nullable soft-references (`conversations.admin_id`/`.product_id`).
- **Two columns were deliberately left unconstrained**, each for a
  specific, documented reason rather than being missed: `events.user_id`
  (an analytics log needs to tolerate anonymous/outlived references, and
  is typed `String` not `UUID` anyway) and `products.contract_id`
  (references a genuinely separate physical database that Postgres
  cannot constrain against).

## Changes Made
Backend (`apps/store-api`):
- `app/modules/orders/routes/payment.py` - added `@transactional()` to
  both routes.
- `app/database.py` - removed `auth_engine`/`brain_engine`/`chat_engine`
  and their `SessionLocal`s; `get_auth_db`/`get_brain_db`/`get_chat_db`
  are now literally `get_db`. Simplified `init_db()`/`dispose_engines()`
  to match.
- `app/config.py` - removed the now-dead `AUTH_DATABASE_URL`/
  `BRAIN_DATABASE_URL`/`CHAT_DATABASE_URL` settings.
- `docker-compose.vps.yml` - removed the matching dead env vars.
- `app/modules/orders/models/order.py`,
  `app/modules/catalog/models/catalog.py`,
  `app/modules/chat/models/chat.py`,
  `app/modules/brain/models/brain.py` - added 14 foreign key constraints.
- `alembic/versions/74a69156cc03_add_missing_foreign_keys.py` - the
  migration applying them.

Database:
- Deleted 9 orphaned `carts` rows (`user_id` not present in `users`).

## Verification
- `python3 -m py_compile` on every changed file - clean.
- Production redeploy after each logical change, each confirmed via
  clean container startup before proceeding.
- Full payment flow test: real account, cart, address, order, payment
  init, webhook - confirmed `Payment` and `Order` rows both persisted
  and updated correctly (`COMPLETED`/`PAID`).
- Role-grant + product-create test confirming the consolidated session
  still correctly reads `ProviderApplication.business_name` via what is
  now the same session used to write the `Product`.
- `pg_constraint` query confirming all 14 new foreign keys exist,
  pointing at the correct tables.
- Final smoke test across both frontends and the catalog API - all 200,
  no errors in `store-api` logs.

## Follow-ups / Deferred
- Convert `UserRole.role`, `ProviderApplication.status`,
  `Product.listing_type`, `Conversation.conversation_type`/`.status`
  to real Postgres enums (matching what `Order.status`/`Payment.status`
  already do correctly).
- Normalize `ProviderApplication.application_type`'s comma-separated
  multi-role string into a junction table.
- Decide whether to build real auto-deploy CI/CD.

## References
- `Backend_and_API/tese-marketplace-2026-10-02-payment-writes-never-committed.md`
- `Backend_and_API/tese-marketplace-2026-10-02-dual-session-consistency-gap.md`
- `Database_and_State/tese-marketplace-2026-10-02-missing-foreign-keys-and-orphaned-carts.md`
- `reports/tese-marketplace-2026-10-02-foundations-alembic-and-dead-code-cleanup.md`
  (the first pass this one continues)

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~1.5 hours from request to verified fix in production
