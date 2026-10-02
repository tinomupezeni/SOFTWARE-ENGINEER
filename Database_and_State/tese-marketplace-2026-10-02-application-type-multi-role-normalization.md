# ProviderApplication.application_type stored multiple roles as one comma-separated string

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
`ProviderApplication.application_type` could hold a value like
`"farmer,supplier"` - multiple roles packed into one string column, a
1NF violation that also made converting the column to a real enum
(see the companion incident report) impossible without first fixing the
underlying data shape. Checked production before assuming this was only
a theoretical/defensive code path and found 2 real rows using it.

## Symptoms
- Not a user-facing error - found while preparing to convert
  `application_type` to a real Postgres enum, which requires a
  single-valued column.

## Environment Details
- **Server/Host:** Production (`tese-db-legacy`, `tese_store` database)
- **Services Affected:** `ProviderApplication` creation/role-granting
- **Related Components:**
  `apps/store-api/app/modules/auth/models/user.py`,
  `apps/store-api/app/modules/auth/services/auth_service.py`,
  `apps/store-api/app/modules/auth/schemas/auth.py`
- **Time First Observed:** 2026-10-02

## Investigation Steps

### 1. Initial Diagnosis
```sql
SELECT application_type, count(*) FROM provider_applications GROUP BY application_type;
-- farmer,supplier | 2
```
Confirmed real data used the multi-value capability, ruling out simply
constraining the column to a single value without a data migration.

### 2. Root Cause Analysis
Checked how the live self-service UI actually creates these rows
(`PartnerSection.tsx`'s `selfGrantMutation`, from an earlier session)
and confirmed it always POSTs one role at a time - a user with multiple
seller roles already ends up with multiple `ProviderApplication` rows
today, one per role. The 2 comma-separated rows were both dated
2026-09-28 with business names like "UI Test Farm Co" and status still
`pending` - leftovers from the old multi-field application form (before
the self-service rewrite made approval automatic), not something the
current live flow can produce.

### 3. Key Findings
- Since the current UI never constructs a multi-value string, the
  correct fix was simpler than a new join table: make
  `application_type` genuinely single-valued (one row per role,
  matching how it's actually used), not add structure for a
  multi-value case the live app doesn't exercise.
- `_grant_roles()` and the duplicate-application check in
  `create_provider_application` both did `.split(",")` on the input -
  vestigial generality for a shape that no longer exists once the
  column is constrained, simplified alongside the schema change.

## Root Cause
The column was designed to optionally hold multiple roles
(comma-separated) from an earlier iteration of the application form,
and that capability was never removed even after the self-service
rewrite made every real code path create one row per role.

## Prevention / Rule
**Guardrail:** A comma-separated or otherwise multi-valued string
column is a signal to check real usage before assuming it's load-bearing
- `grep` every code path that writes to it and confirm whether multi-
value is ever actually constructed, rather than preserving the
capability indefinitely just because old data uses it.

## Solution

### Immediate Fix
Split the 2 real multi-value rows into separate single-role rows before
constraining the column (additive INSERT + UPDATE, not a destructive
operation):
```sql
BEGIN;
INSERT INTO provider_applications (id, user_id, application_type, business_name, description, status, admin_notes, kyc_info, created_at, updated_at)
SELECT gen_random_uuid(), user_id, 'supplier', business_name, description, status, admin_notes, kyc_info, created_at, updated_at
FROM provider_applications WHERE application_type = 'farmer,supplier';
UPDATE provider_applications SET application_type = 'farmer' WHERE application_type = 'farmer,supplier';
COMMIT;
```
Then:
- `ProviderApplication.application_type` converted to a real enum
  (`SellerRoleType`: farmer/supplier/service_provider) - see the
  companion incident report for the column-type migration itself.
- Added `UniqueConstraint("user_id", "application_type")` so the DB
  itself now prevents a duplicate single-role application, not just
  app-level checking.
- `auth_service.py`'s duplicate check now queries `ProviderApplication`
  existence directly (any status), not just granted `UserRole`s, so a
  previously-rejected application can't violate the new unique
  constraint on retry - it gets a clean "you already have an application
  for this role" 400 instead of a raw `IntegrityError`.
- `_grant_roles()` simplified to grant the single role directly, no
  more comma-splitting.
- `ProviderApplicationCreate`/`Update` tightened from plain `str` to
  `Literal["farmer","supplier","service_provider"]` / `Literal["pending","approved","rejected"]`.

```bash
python3 -m py_compile app/modules/auth/services/auth_service.py app/modules/auth/schemas/auth.py   # clean
```
Verified in production: confirmed the split produced exactly one role
per (user_id, application_type) pair with zero duplicates; tested
re-applying for an already-held role (clean 400, "you already have an
application for this role") and applying for a genuinely new role
(200, correctly granted) against a real test account.

### Long-term Fix
None needed - the column is now structurally single-valued and enforced
at the DB level.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `Backend_and_API/tese-marketplace-2026-10-02-enum-conversion-production-outage.md`
  (the incident that happened while deploying this same initiative)
- `reports/tese-marketplace-2026-10-02-enum-conversion-and-application-type-normalization.md`

## References
- `apps/store-api/app/modules/auth/models/user.py`
- `apps/store-api/app/modules/auth/services/auth_service.py`
- `apps/store-api/app/modules/auth/schemas/auth.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~25 minutes from discovery to verified fix in production
