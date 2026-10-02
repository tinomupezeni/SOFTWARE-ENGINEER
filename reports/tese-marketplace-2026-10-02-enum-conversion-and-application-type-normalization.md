# Enum conversion pass: status/type columns to real Postgres enums

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Type:** Architecture Decision / Hardening
**Status:** Completed

## Summary
Final piece of the day's "let's do those not done things" database
hardening work: converted `UserRole.role`, `ProviderApplication.application_type`/
`.status`, `Product.listing_type`, and `Conversation.conversation_type`/
`.status` from plain `String` columns to real Postgres enums, matching
what `Order.status`/`Payment.status` already did correctly. This pass
caused a real, if brief, production outage (see the companion incident
report) - the first genuine incident across all three of today's
hardening passes - and also required actually normalizing
`ProviderApplication.application_type` (found storing multiple roles as
one comma-separated string in 2 real rows) rather than just constraining
it directly.

## Context / Trigger
Direct continuation of the same-day "lets do those not done things"
request - the last 2 items on the deferred list from the first
foundations pass, tackled together since the enum conversion for
`application_type` specifically required resolving its multi-value
design first.

## Scope
**Included:**
- Converting all 7 unconstrained status/type string columns identified
  in the original audit to real Postgres enums.
- Normalizing `ProviderApplication.application_type` to single-valued
  (one role per row), including a data migration for the 2 real
  multi-value rows found in production.
- Adding `UniqueConstraint("user_id", "application_type")`.
- Tightening the corresponding Pydantic schemas from `str` to `Literal`
  types for input validation.

**Explicitly excluded:**
- Deciding on real auto-deploy CI/CD - still the one remaining item from
  the very first foundations report, not part of database hardening and
  not picked up this round.

## Method
Before converting anything, queried the real distinct values in every
target column (`SELECT col, count(*) FROM table GROUP BY col`) to catch
surprises like the comma-separated `application_type` rows before
writing any migration - the same discipline used for the FK work earlier
the same day.

The conversion itself caused a production incident (full detail in the
companion report) that required live diagnosis and recovery: SQLAlchemy's
`Enum(PyEnumClass)` defaults to matching by the enum member's `.name`,
not `.value`, which only breaks when a column already holding real
lowercase data (written during its prior life as a `String` column) is
converted - as opposed to `Order.status`/`Payment.status`, which were
`Enum`-typed from the start and so never hit the mismatch. Recovered
live: added `values_callable` to every new enum, worked around the
sandbox's correct block on an unconfirmed `DROP TYPE` by renaming the
new enum types instead of dropping the accidentally-created wrong ones
(a non-destructive path that didn't require waiting on a permission
round-trip while production was down), then fixed a second, cascading
Pydantic `Literal`-vs-enum-instance validation failure discovered
immediately after. Cleaned up the 6 orphaned wrong-labeled types only
once production was stable again and with explicit confirmation.

For the actual schema migration (once the incident was resolved):
generated via Alembic `--autogenerate`, then hand-corrected it, since
autogenerate's `VARCHAR -> ENUM` output doesn't include the required
`USING` cast and doesn't handle the `DROP DEFAULT` / `SET DEFAULT` dance
needed for the two columns with a server-side default
(`categories.listing_type`, `products.listing_type`). Verified the
migration's correctness with a direct SQL probe after applying it - a
raw `INSERT` with an invalid enum value correctly rejected by Postgres
itself, confirming real DB-level enforcement rather than just
application-level validation.

## Decisions & Findings
- **`application_type` didn't need a new join table** - checking real
  usage (how the live self-service UI actually constructs these rows)
  showed every current code path already creates one row per role; the
  comma-separated capability was a leftover from an earlier application-
  form design, used by exactly 2 rows, both pre-dating the self-service
  rewrite. Splitting those 2 rows and constraining the column directly
  was the right-sized fix, not a bigger structural change.
- **The duplicate-application check moved from `UserRole` to
  `ProviderApplication`** - checking only granted roles would have let a
  resubmission after admin rejection crash into the new unique
  constraint with a raw `IntegrityError`; checking application existence
  directly catches it first with a clean 400.
- **`Order.status`/`Payment.status` don't have the enum-matching bug**
  that hit every other conversion - verified by checking they were
  `Enum`-typed from day one (no prior `String`-column phase with
  mismatched data), so left untouched rather than "fixed" unnecessarily.
- **Response schemas need plain `str`, not `Literal`, for enum-backed
  ORM fields** - Pydantic v2's `Literal` validator rejects a `(str,
  Enum)` instance despite it string-equaling correctly; `Literal` stays
  useful on Create/Update schemas (real input validation) but breaks
  response serialization once the ORM returns actual enum instances.

## Changes Made
Backend (`apps/store-api`):
- `app/modules/auth/models/user.py` - `UserRole.role`,
  `ProviderApplication.application_type`/`.status` converted to
  `Enum(...)` with `values_callable`; added `SellerRoleType`/
  `ApplicationStatus` enums and the unique constraint.
- `app/modules/catalog/models/catalog.py` - `Category.listing_type`/
  `Product.listing_type` converted to a shared `ListingType` enum.
- `app/modules/chat/models/chat.py` - `Conversation.conversation_type`/
  `.status` converted to `ConversationType`/`ConversationStatus` enums.
- `app/modules/auth/schemas/auth.py`,
  `app/modules/catalog/schemas/catalog.py` - `Literal` types on
  Create/Update schemas; plain `str` overrides on Response schemas.
- `app/modules/auth/services/auth_service.py` - simplified
  `_grant_roles`/`create_provider_application` for single-valued
  `application_type`; duplicate check now checks `ProviderApplication`
  existence.
- `alembic/versions/94057531b79d_convert_status_type_columns_to_enums.py` -
  the hand-corrected migration applying all 7 conversions.

Database:
- Split 2 multi-value `provider_applications` rows into separate rows.
- Dropped 6 orphaned, wrong-labeled enum types left over from the
  incident, once production was confirmed stable.

## Verification
- `python3 -m py_compile` on every changed file at each step.
- Full smoke test after every deploy (site, admin dashboard, catalog
  products/categories) - confirmed clean before declaring each step done.
- Direct SQL probe: an invalid raw `INSERT` into `user_roles.role`
  correctly rejected by Postgres with `invalid input value for enum
  user_role_type` - real DB-level enforcement confirmed, not just
  app-level.
- Re-application and new-role-application tests against a real test
  account, confirming the normalized `application_type` and its unique
  constraint behave correctly end-to-end.
- `alembic current` on the production container reports the final
  migration as head, matching the database's `alembic_version` table.

## Follow-ups / Deferred
- Decide whether to build real auto-deploy CI/CD - the one remaining
  item from the original foundations list, unrelated to database work.

## References
- `Backend_and_API/tese-marketplace-2026-10-02-enum-conversion-production-outage.md`
- `Database_and_State/tese-marketplace-2026-10-02-application-type-multi-role-normalization.md`
- `reports/tese-marketplace-2026-10-02-database-hardening-transactions-engines-fks.md`
  (the pass immediately before this one, same day)
- `reports/tese-marketplace-2026-10-02-foundations-alembic-and-dead-code-cleanup.md`
  (the first pass that started this day's work)

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~1 hour from start to verified stable in production, including incident recovery
