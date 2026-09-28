# Category listing_type sent by admin-dashboard was silently discarded server-side

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
`admin-dashboard`'s `AddCategoryModal.tsx` already had a "Listing Type"
selector (Product/Service/Supplier Product) and sent `listing_type` in
every category-create payload - but the `Category` SQLAlchemy model had no
`listing_type` column at all. `catalog_service.py`'s `create_category`/
`update_category` explicitly stripped the field before constructing the
ORM object (`# listing_type is for frontend compatibility, remove if not
in model`), so every category silently landed as a single undifferentiated
type regardless of what the admin selected in the UI. Found while
implementing the user's request to seed categories for all 3 seller types
- seeding would have been pointless without this actually working.

## Symptoms
- Not a user-facing error report - discovered by reading the code path
  while implementing category seeding. `admin-dashboard`'s category form
  gave every appearance of working (no error, category created
  successfully) while quietly ignoring the type selection.
- Consequence in the wild: every category ever created (2 existed in
  production before this fix) appeared identically in every seller's
  category picker regardless of listing type, since nothing distinguished
  them.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-store-api`
  container, `tese_store` database)
- **Services Affected:** Category creation/editing from `admin-dashboard`;
  category selection in `customer-store`'s seller listing form
- **Related Components:**
  `apps/store-api/app/modules/catalog/models/catalog.py`,
  `apps/store-api/app/modules/catalog/services/catalog_service.py`,
  `apps/store-api/app/modules/catalog/schemas/catalog.py`,
  `apps/admin-dashboard/src/components/AddCategoryModal.tsx`
- **Time First Observed:** 2026-09-28

## Investigation Steps

### 1. Initial Diagnosis
Before seeding categories for all 3 listing types, checked whether the
`Category` model could even represent a type per category. Found
`CategoryBase.listing_type: Optional[str] = "product" # Added for frontend
compatibility` in the schema - the comment itself was the tell that this
field was known to exist on the frontend but not really supported.

### 2. Root Cause Analysis
Read `catalog_service.py`'s `create_category`/`update_category` and found
both explicitly filtering `listing_type` out of the data dict before
constructing/updating the `Category` ORM object, with a comment
acknowledging the model didn't have the column. Checked `admin-dashboard`
independently (`AddCategoryModal.tsx`) and confirmed it already had a
working "Listing Type" `<Select>` sending the field on every request -
the frontend half of this feature had been built correctly; only the
backend/model half was never finished.

### 3. Key Findings
- This wasn't a case of a frontend bug needing a backend feature built
  from scratch - the backend schema and the admin UI already agreed on
  the contract (`listing_type: "product" | "supplier_product" |
  "service"`); only the persistence layer (model column + service logic)
  was missing, making this a narrow, well-scoped gap rather than new
  feature work.
- `CategoryResponse` (extending `CategoryBase`) meant every category read
  from the API also always reported `listing_type: "product"` by default,
  independent of reality - masking the gap on read as well as write.

## Root Cause
The `listing_type` field was added to the Pydantic schema and to
`admin-dashboard`'s create form (anticipating the feature) before the
corresponding `Category` model column was added, and the service layer
was patched to defensively strip the field rather than the model being
completed - leaving the frontend half of the feature shipped with no
backend behind it.

## Prevention / Rule
**Guardrail:** A comment like `# X is for frontend compatibility, remove
if not in model` is itself a signal of an incomplete backend feature, not
a permanent design decision - any such comment found during unrelated work
should be treated as a known gap to close, not code to route around
further. More concretely: a Pydantic schema field with no corresponding
SQLAlchemy model column should fail loudly (e.g., a startup-time schema/
model consistency check for fields explicitly marked as needing backend
work) rather than being silently dropped in the service layer.

## Solution

### Immediate Fix
- `apps/store-api/app/modules/catalog/models/catalog.py`: added
  `listing_type = Column(String(30), nullable=False, default="product",
  server_default="product")` to `Category`.
- `apps/store-api/app/modules/catalog/schemas/catalog.py`: `listing_type`
  now a `Literal["product", "supplier_product", "service"]` instead of an
  unconstrained `Optional[str]`.
- `apps/store-api/app/modules/catalog/services/catalog_service.py`:
  `create_category`/`update_category` no longer filter `listing_type` out
  - it's persisted like any other field.
- `apps/store-api/migrations/add_category_listing_type.py`: idempotent
  migration adding the column (`ALTER TABLE categories ADD COLUMN IF NOT
  EXISTS listing_type VARCHAR(30) NOT NULL DEFAULT 'product'`).

```bash
python3 -m py_compile app/modules/catalog/models/catalog.py \
  app/modules/catalog/schemas/catalog.py \
  app/modules/catalog/services/catalog_service.py   # clean

docker exec tese-store-api python -m migrations.add_category_listing_type
```

Deploy note: the new code was rolled out to the `store-api` container
*before* the migration ran, which crash-looped the container on startup
(`UndefinedColumn: categories.listing_type does not exist` - a startup
query already selected the new column). Fixed by running the `ALTER
TABLE` directly against Postgres to unblock the container, then running
the migration script normally (idempotent, no-ops on the already-added
column) for the record. Confirmed in production: `store-api` container
stable (`Up`, no restart loop), `GET /api/catalog/categories?listing_type=service`
returns only service categories.

### Long-term Fix
The seller-facing category picker in `customer-store` now also filters by
`listing_type` client-side (see the companion report,
`reports/tese-marketplace-2026-09-28-category-scoping-and-seed.md`), so
the gap this entry closes is now actually load-bearing rather than latent.

## Prevention
- [x] Code changes required (done this session)
- [ ] Deploy order rule: for any change that adds a DB column a
      startup-path query depends on, run the migration before recreating
      the app container, not after (this session did it the wrong order
      and had to recover live)

## Related Issues
- `reports/tese-marketplace-2026-09-28-category-scoping-and-seed.md` (the
  seeding initiative that surfaced this bug)
- `Backend_and_API/tese-marketplace-2026-09-28-sellers-could-create-own-categories.md`
  (earlier same-day fix narrowing who can write categories at all)

## References
- `apps/store-api/app/modules/catalog/models/catalog.py`
- `apps/store-api/app/modules/catalog/services/catalog_service.py`
- `apps/store-api/app/modules/catalog/schemas/catalog.py`
- `apps/admin-dashboard/src/components/AddCategoryModal.tsx`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~15 minutes from discovery to verified fix in production
