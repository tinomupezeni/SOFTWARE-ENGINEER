# Production `products_product` Table Missing `category` Column Entirely — Every "Add Product" Returned 500

**Date:** 2026-09-12
**Project:** CRM
**Environment:** Production (restk-vps, `crm.restksolutions.co.zw`)
**Severity:** Critical (core feature down, actively hitting real users mid-trial)
**Status:** Resolved

## Summary
The user reported traders couldn't add products during their live trial. Backend logs showed every `POST /api/v1/products/` failing with `psycopg2.errors.UndefinedColumn: column "category" of relation "products_product" does not exist`. The column the model has always expected simply wasn't there — production's table instead had a `category_id` foreign key against an orphaned `products_productcategory` table that doesn't exist anywhere in the current codebase.

## Symptoms
- Real trader requests: `POST /api/v1/products/` → `500`, repeatedly, since the morning of 2026-09-12 (confirmed via `docker logs crm-backend-1`, multiple distinct client sessions hitting `/products/new`).
- Exact error: `psycopg2.errors.UndefinedColumn: column "category" of relation "products_product" does not exist`, raised from the `INSERT INTO products_product (..., "category", ...)` Django generated from `ProductSerializer.create()`.
- `\d products_product` in production showed `category_id bigint` (a FK to `products_productcategory`) where a plain `category varchar(100)` should be.

## Environment Details
- **Server/Host:** `restk-vps` (`~/apps/crm`), `crm-backend-1` container
- **Services Affected:** `products` app — `POST`/anything touching `Product.category` (create, and any read that touched the field, though reads happened to still 200 since DRF only selects declared serializer fields lazily per query, not a blanket `SELECT *`)
- **Related Components:** `apps/products/models.py` (`Product.category` CharField, unchanged since `0001_initial`), the live Postgres schema, `django_migrations` table
- **Time First Observed:** reported 2026-09-12; backend logs show failures from at least 07:32 UTC that morning

## Investigation Steps

### 1. Initial Diagnosis
`docker logs crm-backend-1 | grep 'POST /api/v1/products'` showed a run of `500`s going back hours, all from real client IPs on `/products/new` — not something caused by the backend redeploy from the previous day (that only touched `sales`/`quotations` code paths).

### 2. Root Cause Analysis
```bash
docker logs crm-backend-1 | grep -A40 'Internal Server Error: /api/v1/products'
# psycopg2.errors.UndefinedColumn: column "category" of relation "products_product" does not exist

docker compose exec -T db psql -U $DBUSER -d $DBNAME -c '\d products_product'
# category_id | bigint  -- an FK, not the CharField the model defines

docker compose exec -T db psql -U $DBUSER -d $DBNAME -c '\d products_productcategory'
# a whole separate table, FK'd from products_product.category_id, that has
# no corresponding model anywhere in the current git history

docker compose exec -T db psql -U $DBUSER -d $DBNAME -c \
  "SELECT app, name, applied FROM django_migrations WHERE app='products' ORDER BY id;"
# products | 0008_create_product_sku_sequence               | 2026-05-08
# products | 0008_productcategory_alter_product_category    | 2026-07-09
# — neither file exists anywhere in apps/products/migrations/ (which only
#   goes up to 0007_product_product_type.py)
```

### 3. Key Findings
- A "categories as their own model" feature (`ProductCategory` + `Product.category` as a FK) was built, migrated, and deployed straight to production on 2026-07-09 — then later reverted in the git repo (the migration file and model changes removed) **without ever reversing the database change**. The column that migration created/renamed was never restored.
- Two migrations recorded as `applied` in `django_migrations` for the `products` app have no corresponding file in the current repo at all (`0008_create_product_sku_sequence`, `0008_productcategory_alter_product_category`) — evidence of at least one other similarly-orphaned migration (the SKU-sequence one) that didn't cause an outage only because current code generates SKUs in Python rather than via a DB sequence.
- Django's own `makemigrations`/`migrate` never flagged this: migration **state** (derived purely from the files in the repo, 0001–0007) has always said `category` is a CharField, matching the model — state tracking has no way to know the *physical* table was mutated out-of-band by a migration file that no longer exists. `manage.py migrate` reporting "no migrations to apply" the day before this was found is consistent with, not contradictory to, the drift.
- Zero data was at risk: production had exactly 1 product total, 0 with `category_id` set, and `products_productcategory` had 0 rows.

## Root Cause
An abandoned feature branch's database migration was applied directly to production and never reverted after the feature itself was reverted in git, leaving the live schema physically different from what every version of the model since `0001_initial` has expected — invisibly, since Django's migration state has no mechanism to detect drift introduced by a migration file that's since been deleted from the codebase.

## Prevention / Rule
**Guardrail:** Treat any migration file as append-only and immutable once it has been applied to a real environment (staging or production) — reverting a feature must ship a *new forward migration* that undoes the schema change, never a plain deletion of the already-applied migration file. Back this with a CI check that fails the build if any migration name recorded in a target environment's `django_migrations` table has no corresponding file in the current checkout.

Django's migration state is derived purely from files present in the repo, so deleting an applied migration silently disconnects the live schema from what the model believes exists — exactly what happened here, and `makemigrations --check` reported clean the entire time.

## Solution

### Immediate Fix
Wrote `apps/products/migrations/0008_fix_category_column_drift.py` — a `RunSQL`-only migration (no model state change needed, since Django's state already believed `category` was a CharField) that:
```sql
ALTER TABLE products_product ADD COLUMN IF NOT EXISTS category varchar(100) NOT NULL DEFAULT '';
ALTER TABLE products_product DROP COLUMN IF EXISTS category_id;
DROP TABLE IF EXISTS products_productcategory;
```
Verified end-to-end on a scratch Postgres before touching production: clean apply, `makemigrations --check --dry-run` → "No changes detected", full `apps/products` test suite green (15/15).

Applied to production via `docker cp` into the running `crm-backend-1` container + `manage.py migrate products` (a full image rebuild wasn't needed just to ship one migration file). Confirmed live via `\d products_product` (column present, `category_id`/FK/orphaned table gone) and a real `Product.objects.create(..., category="Test Category")` in a production Django shell, immediately deleted after confirming it worked.

### Long-term Fix
- Committed the migration (`0344c1d`) so any other environment (or a rebuilt VPS) gets the same fix automatically via normal `migrate`.
- Not yet done: track down what `0008_create_product_sku_sequence` (the *other* orphaned migration, from 2026-05-08) actually did to the schema and whether it left anything else drifted — it didn't cause an outage, but that's luck, not verification.

## Prevention
- [ ] Never deploy a migration to production without a corresponding commit on `main` — if a feature is later reverted in git, its migration must be reverted (a real down-migration or an explicit compensating one) in the same change, not left to drift silently.
- [ ] A periodic `makemigrations --check` alone is insufficient to catch this class of drift (as demonstrated here — it reported clean the whole time). Consider a periodic live schema diff against what the current migration graph *should* produce (e.g. `sqlmigrate` output reconciled against `\d` on the real table) for at least the core tenant models.
- [ ] Audit the other orphaned migration (`0008_create_product_sku_sequence`) for any similar un-reverted drift.
- [ ] This is another instance of the deploy-process gap already logged separately: production has no git checkout and CI/CD doesn't actually deploy what it builds (see the CI/CD drift entry from 2026-09-11) — a real deploy pipeline with migrations tracked against a known-good source would have caught this class of problem structurally, not just this one instance of it.

## Related Issues
- [CI/CD publishes to GHCR, production runs from Docker Hub build-in-place with no git access](../DevOps_and_Infrastructure/CRM-2026-09-11-cicd-deploy-drift-ghcr-vs-dockerhub.md)
- [nginx cached stale backend IP after container recreate](../DevOps_and_Infrastructure/CRM-2026-09-11-nginx-stale-backend-ip-after-container-recreate.md) — same VPS, same general theme of production drifting from what the repo assumes

---

**Resolved By:** Claude Code
**Time to Resolution:** ~35 minutes (diagnosis to verified live fix)
