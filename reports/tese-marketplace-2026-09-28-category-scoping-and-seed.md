# Scope categories per listing type and seed starter categories for all 3 seller types

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, store-api / customer-store)
**Type:** Scope Decision / Data Seed
**Status:** Completed

## Summary
Categories are shared, admin-managed data (per the same-day decision in
`Backend_and_API/tese-marketplace-2026-09-28-sellers-could-create-own-categories.md`),
but production only had 2 categories total and no way to scope a category
to a specific seller type - a farmer's produce dropdown would show a
service category and vice versa. Closed the underlying schema gap that
made scoping impossible (see the companion bug entry), then seeded 18
starter categories (6 produce, 7 supply, 6 service) so all three seller
types have a real, correctly-scoped category list to pick from.

## Context / Trigger
User request, verbatim: "lets seed categories for all 3" - a direct
follow-up to the same-day decision to make categories admin-managed.
Before seeding, checked whether the category model could even represent
"which seller type is this category for," and found it couldn't (see
`Backend_and_API/tese-marketplace-2026-09-28-category-listing-type-silently-dropped.md`)
- so this work started as a data-seeding task and became a small schema
fix plus a seed.

## Scope
**Included:**
- Adding a `listing_type` column to `Category` (product / supplier_product
  / service) and actually persisting it (see the linked bug entry for why
  this was needed).
- An optional `listing_type` query filter on `GET /categories` and
  `GET /admin/categories`.
- Filtering the seller-facing category `<select>` in
  `PartnerSection.tsx`'s Add/Edit Listing form to only show categories
  matching the listing type currently being added.
- Seeding 18 categories across the 3 types, plus backfilling the one
  pre-existing real category ("Fruits" → `product`) and removing one
  leftover test/junk category ("Category Msg 1782111281") found in
  production during this work.

**Explicitly excluded:**
- No changes to `admin-dashboard`'s `AddCategoryModal.tsx` - it already
  sent `listing_type` correctly; the gap was entirely server-side.
- No category hierarchy/parent-child restructuring - `parent_id` already
  exists on the model and was left as-is; this pass only added the
  type dimension.
- No public storefront "shop by category" browsing changes - out of scope
  for this request, though the new `listing_type` filter param on the
  public `GET /categories` route is available if that's built later.

## Method
Checked whether the model already supported per-type categories before
writing any seed data, since seeding into an unscoped/shared list would
have made the UX worse, not better (a farmer would see "Tractor Hire" as
a selectable category for a tomato listing). That check surfaced the
`listing_type`-discarded bug, logged separately per the standing
bug-logging rule, then fixed it as a prerequisite for the seed to mean
anything.

Categories were seeded via a small, idempotent Python migration script
(`migrations/seed_categories.py`, following this repo's existing
`migrations/add_messaging_tables.py` convention: plain script, not
Alembic - this project doesn't use Alembic despite it being a dependency)
rather than one-off `INSERT` statements, so the same categories can be
re-seeded safely in another environment (e.g. staging, or if the
production DB is ever reset) with `python -m migrations.seed_categories`.

## Decisions & Findings
- **Categories stay a flat, non-type-namespaced list at the DB level** -
  `listing_type` is a column on the same `categories` table, not three
  separate tables or a compound key with slug - simplest schema that
  still lets each seller type see a distinct picker.
- **Filtering happens client-side in `PartnerSection.tsx`** (`categories.filter(c
  => c.listing_type === listingType)`) rather than via the new backend
  query param, since the full category list is small (~19 rows) and the
  UI already fetches it all once per session; the backend `listing_type`
  query param was still added since it's cheap and gives `admin-dashboard`
  or a future storefront category browser a server-side filtering option
  without another round of backend changes.
- **Seed set chosen to be a reasonable, genuinely useful starting
  taxonomy** rather than placeholder data: 6 produce (Vegetables, Fruits,
  Grains & Cereals, Dairy & Eggs, Poultry & Livestock, Herbs & Spices), 7
  supply (Seeds & Seedlings, Fertilizers & Soil Additives, Pesticides &
  Herbicides, Farm Equipment & Machinery, Irrigation Supplies, Animal
  Feed, Tools & Hardware), 6 service (Tractor & Machinery Hire, Land
  Preparation, Harvesting Services, Logistics & Transport, Agronomy &
  Consulting, Veterinary Services) - admins can add more later via
  `admin-dashboard`, now that `listing_type` actually persists.
- **Found and removed a leftover junk category** ("Category Msg
  1782111281") during this work - clearly test data from earlier
  automated verification this session, not real content; removed as
  cleanup since it would otherwise have appeared as a selectable produce
  category (defaulted to `listing_type='product'` by the migration).

## Changes Made
Backend (`apps/store-api`):
- `app/modules/catalog/models/catalog.py` - added `listing_type` column
  to `Category`.
- `app/modules/catalog/schemas/catalog.py` - `listing_type` now a
  `Literal["product", "supplier_product", "service"]`.
- `app/modules/catalog/services/catalog_service.py` -
  `create_category`/`update_category` persist `listing_type`;
  `get_categories` accepts an optional `listing_type` filter.
- `app/modules/catalog/routes/catalog.py` - `GET /categories` and
  `GET /admin/categories` accept `?listing_type=`.
- `migrations/add_category_listing_type.py` - idempotent column migration.
- `migrations/seed_categories.py` - idempotent category seed + junk-row
  cleanup.

Frontend (`apps/customer-store`):
- `features/customer-profile/components/PartnerSection.tsx` - `Category`
  interface gained `listing_type`; category `<select>` filters to
  `categoriesForType` (matching the listing type currently being added)
  instead of the full unfiltered list.

## Verification
- `python3 -m py_compile` on all changed backend files - clean.
- `npx tsc --noEmit` and `pnpm --filter customer-store build` - clean.
- Ran the migration and seed script against the production DB via
  `docker exec tese-store-api python -m migrations.<script>`.
- `SELECT listing_type, count(*) FROM categories GROUP BY listing_type`
  in production confirms 6 product / 7 supplier_product / 6 service.
- `GET https://tesemarket.com/api/catalog/categories?listing_type=service`
  returns exactly the 6 seeded service categories.
- Confirmed `store-api` container stable after deploy (see the linked bug
  entry for a deploy-ordering issue hit and recovered from along the way).

## Follow-ups / Deferred
- `admin-dashboard` has no edit/delete UI for existing categories (create
  only) - unrelated pre-existing gap, noted again here since it's now
  more relevant (an admin may want to retype a miscategorized entry).
- No public "shop by category" browsing UI exists yet in `customer-store`
  to make use of the new `listing_type` filter param on the public
  `GET /categories` route - available whenever that's built.

## References
- `Backend_and_API/tese-marketplace-2026-09-28-category-listing-type-silently-dropped.md`
  (the bug this work surfaced and fixed as a prerequisite)
- `Backend_and_API/tese-marketplace-2026-09-28-sellers-could-create-own-categories.md`
  (same-day decision making categories admin-managed, which this seeds
  data for)
- Key files: `apps/store-api/app/modules/catalog/models/catalog.py`,
  `apps/store-api/migrations/seed_categories.py`,
  `apps/customer-store/src/features/customer-profile/components/PartnerSection.tsx`

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~35 minutes from request to verified seed in production
