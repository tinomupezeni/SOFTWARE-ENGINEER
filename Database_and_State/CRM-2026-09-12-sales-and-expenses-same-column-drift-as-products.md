# Full-Codebase Schema Audit Found the Same Column-Drift Bug in Sales and Expenses

**Date:** 2026-09-12
**Project:** CRM
**Environment:** Production (restk-vps, `crm.restksolutions.co.zw`)
**Severity:** Critical (two more core features silently guaranteed to fail on first use)
**Status:** Resolved

## Summary
After fixing `products_product.category` (see the earlier entry today), the user asked for a full audit of the codebase for the same class of failure. Wrote a schema-introspection script that compares every Django model's fields against the live production database, table by table. It found the identical pattern in two more places: `sales_sale.payment_status` and `expenses_expense.category` were both missing from production, each replaced by an orphaned foreign-key column from a since-reverted feature.

## Symptoms
- No user had hit these yet (confirmed via backend request logs — zero `POST /api/v1/sales/` or `POST /api/v1/expenses/` since the backend was last redeployed), but a direct test in a production Django shell reproduced both immediately:
  - `Sale.objects.create(...)` → `ProgrammingError: column "payment_status" of relation "sales_sale" does not exist`
  - `Expense.objects.create(...)` → `ProgrammingError: column "category" of relation "expenses_expense" does not exist`

## Environment Details
- **Server/Host:** `restk-vps` (`~/apps/crm`), `crm-backend-1`
- **Services Affected:** `sales` (any Sale creation), `expenses` (any Expense creation)
- **Related Components:** `apps/sales/models.py` (`Sale.payment_status`, unchanged since `0001_initial`), `apps/expenses/models.py` (`Expense.category`, unchanged since `0001_initial`), live Postgres schema, `django_migrations`
- **Time First Observed:** found proactively via audit, 2026-09-12; not yet hit by a real user for either table

## Investigation Steps

### 1. Initial Diagnosis
Rather than spot-checking, wrote a script (run via `manage.py shell`) that, for every registered Django model: confirms its table exists in the live DB, then diffs `model._meta.local_fields` (fields whose columns actually live on that table — excludes M2M and multi-table-inheritance parent fields, which caused early false positives) against `connection.introspection.get_table_description()`. Reports both missing columns (model expects it, DB doesn't have it) and extra columns (DB has it, model doesn't expect it).

### 2. Root Cause Analysis
The audit's "extra columns" output immediately pointed at the same shape of bug as the Products fix:
```
sales.Sale (table 'sales_sale'): extra columns ['payment_status_id', 'public_id']
expenses.Expense (table 'expenses_expense'): extra columns ['category_id']
```
Cross-checked against `django_migrations`, which showed (same pattern as Products — see that entry):
```
sales    | 0007_sale_public_id                          | 2026-05-08
expenses | 0002_expensecategory_alter_expense_category  | 2026-07-09
sales    | 0007_salestatus_and_more                     | 2026-07-09
```
None of these three migration names have a corresponding file anywhere in the current repo.

### 3. Key Findings
- **Timing makes the mechanism clear**: both phantom-migration batches (2026-05-08 and 2026-07-09) were applied *before* this session started, and the backend Docker image had not been rebuilt since 2026-07-09 either — meaning the two-months-stale backend code and the "drifted" schema were mutually consistent the whole time (the old code presumably still had the FK-based category/status/public_id fields). It was only after yesterday's backend redeploy (2026-09-11, to ship the sale-variant and quotations fixes — see that entry) — which pulled in current `main`, where these features had already been reverted in source without a down-migration — that the code and the live schema stopped agreeing. That redeploy is what turned this from a hidden-but-consistent old deploy into active drift for every app that had one of these abandoned migrations.
- **Zero data at risk for either table**: `sales_sale` had 0 rows and the orphaned `sales_salestatus` table had 0 rows. `expenses_expense` had 8 real rows, none with `category_id` set, and the orphaned `expenses_expensecategory` table had exactly 1 unused row.
- **A fourth phantom migration** (`products.0008_create_product_sku_sequence`, 2026-05-08) turned out to be harmless — it created a `product_sku_seq` Postgres sequence that no column defaults to and no code references (SKUs are generated in Python from a row count). Dropped it anyway for cleanliness.
- **The audit script itself needed two iterations**: the first pass used `model._meta.get_fields()`, which includes inherited fields from multi-table-inheritance parents (falsely flagged `contacts.Client`, whose own local columns were actually fine) and many-to-many fields (falsely flagged `auth.Group.permissions`, `accounts.User.groups`/`user_permissions`, which live in join tables, not a column on the parent). Switching to `model._meta.local_fields` fixed both false-positive classes.
- **After fixing all three**, a full re-run of the audit across every app/model in the codebase came back completely clean — no missing columns, no unexplained extra columns anywhere else.

## Root Cause
Same as the Products entry: at least two abandoned feature branches (a "categories/status as first-class models" effort, and a separate "public sharing links" effort) had their migrations applied directly to production, then were reverted in git without the corresponding database changes ever being reversed. This is not a one-off — it's now confirmed to have happened at least three times across three different apps (Products, Sales, Expenses), all in the same two deploy windows (2026-05-08, 2026-07-09).

## Prevention / Rule
**Guardrail:** Turn this session's ad hoc schema-introspection script (`model._meta.local_fields` vs. `connection.introspection.get_table_description()`, per model) into a scheduled CI job or pre-deploy gate that runs automatically against the target environment — fail the deploy loudly on any missing/extra column, rather than waiting for a user (or luck) to trip over the next one.

This bug class had already recurred silently across three separate apps before anyone looked — a proactive, automated version of the exact check that found it here is the only thing that catches instance four before a real user does.

## Solution
Same `RunSQL`-only pattern as the Products fix (Django's migration *state* already believed these columns were plain fields, so no model-state change was needed — only the physical table):
- `apps/sales/migrations/0007_fix_payment_status_column_drift.py`: adds back `payment_status varchar(10) DEFAULT 'paid'`, recreates the original `(organization, payment_status)` index under its expected name, drops `payment_status_id`/`public_id`/`sales_salestatus`.
- `apps/expenses/migrations/0002_fix_category_column_drift.py`: adds back `category varchar(20) DEFAULT 'other'` (matching the model's `Category.OTHER` default), drops `category_id`/`expenses_expensecategory`.
- `apps/products/migrations/0009_drop_orphaned_sku_sequence.py`: drops the unused `product_sku_seq`.

All three verified on a scratch Postgres before touching production (clean apply, `makemigrations --check` clean, full 128-test backend suite green), then applied live via `docker cp` + `manage.py migrate` (no image rebuild needed). Confirmed with real `Sale.objects.create(...)` and `Expense.objects.create(...)` calls in a production shell — both succeeded, cleaned up immediately after. Committed as `1f5c992`.

## Prevention
- [x] Full-codebase audit completed — confirmed no other app has this pattern right now.
- [ ] The underlying process gap is the same one already flagged in the Products entry and the CI/CD drift entry: there's no guardrail that catches "a migration was applied to prod that isn't in the git history anymore." Worth turning the audit script used here into a standing check (even a manual pre-deploy step) rather than something that only gets run when a user reports a symptom.
- [ ] Clean up the now-purely-historical phantom rows in `django_migrations` (`expenses.0002_expensecategory_alter_expense_category`, `products.0008_create_product_sku_sequence`, `products.0008_productcategory_alter_product_category`, `sales.0007_sale_public_id`, `sales.0007_salestatus_and_more`) — harmless to leave, but confusing for the next person who runs `showmigrations`.

## Related Issues
- [`products_product.category` missing entirely](./CRM-2026-09-12-products-category-column-missing.md) — the original instance of this exact pattern, found first
- [CI/CD publishes to GHCR, production runs from Docker Hub build-in-place](../DevOps_and_Infrastructure/CRM-2026-09-11-cicd-deploy-drift-ghcr-vs-dockerhub.md) — same root process gap (no real deploy pipeline reconciling code and database)

---

**Resolved By:** Claude Code
**Time to Resolution:** ~45 minutes (audit script, verification, three migrations, applied and confirmed live)
