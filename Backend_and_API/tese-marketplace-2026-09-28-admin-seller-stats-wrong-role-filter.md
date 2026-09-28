# Admin "Sellers" tab and seller stats always return zero (wrong role string)

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`AuthService.get_users(role="sellers")` and `AuthService.get_user_stats()` in
`apps/store-api/app/modules/auth/services/auth_service.py` filtered
`UserRole.role == "seller"`. No code path in the application ever grants a
user the role string `"seller"` — the real self-listing roles granted via
`ProviderApplication` approval are `supplier` and `service_provider` (and,
as of this session, `farmer`). As a result the admin dashboard's "Sellers"
user-management tab and the `total_sellers`/`active_sellers` figures in
`get_user_stats()` were silently always empty/zero, regardless of how many
approved partners existed.

## Symptoms
- Admin dashboard "Sellers" filter (`GET /auth/admin/users?type=sellers`)
  always returned an empty list even with approved suppliers/service
  providers in the database.
- `GET /auth/admin/users/stats` always reported `total_sellers: 0` and
  `active_sellers: 0`.
- No error was raised anywhere — the query was valid SQL, it just matched
  nothing, so this was silent and easy to miss without a seeded "seller".

## Environment Details
- **Server/Host:** local/dev (store-api FastAPI service)
- **Services Affected:** `store-api` auth module, admin-dashboard user
  management and stats views that consume these endpoints
- **Related Components:** `apps/store-api/app/modules/auth/services/auth_service.py`,
  `apps/store-api/app/modules/auth/models/user.py` (`RoleType`, `UserRole`)
- **Time First Observed:** 2026-09-28, while auditing the self-listing
  (farmer/supplier/service-provider) role model to add farmer self-listing
  support

## Investigation Steps

### 1. Initial Diagnosis
While tracing how a user becomes able to self-list a product (via
`ProviderApplication` approval → `UserRole` grant), found that
`AuthService.update_application_status()` grants roles taken verbatim from
`ProviderApplication.application_type` (comma-split), which are always
`supplier` and/or `service_provider` (now also `farmer`) — never `seller`.

### 2. Root Cause Analysis
```bash
grep -rn '"seller"' apps/store-api/app/modules/auth/services/auth_service.py
```
Found two independent filters both hardcoding the literal string `"seller"`,
with no corresponding grant path anywhere in the codebase that ever writes
that value into `UserRole.role`.

### 3. Key Findings
- `RoleType` (the intended enum of valid roles in `auth/models/user.py`) did
  not even define a `SELLER` member — confirming `"seller"` was never a
  designed role, just a stray/typo'd string literal.
- `UserRole.role` is a plain `String(50)` column, not constrained by the
  `RoleType` enum at the DB or query layer, so nothing caught the mismatch
  between the string used to grant roles and the string used to query them.

## Root Cause
Two call sites (`get_users`, `get_user_stats`) queried for the role string
`"seller"` as a stand-in for "any self-listing/partner role," but the actual
role-granting code (`update_application_status`) never produces that string
— it grants the specific roles named in the approved application
(`supplier`, `service_provider`, and now `farmer`). The two sides of this
relationship (grant vs. query) were written independently as raw string
literals with no shared source of truth, so they drifted.

## Prevention / Rule
**Guardrail:** Role-name string literals for the self-listing role set must
only ever be written once, as a shared constant/enum, and both the
role-granting code and any role-based queries must import and use it —
never re-type the literal. Concretely: `auth_service.py` now defines
`SELLER_ROLES = ["farmer", "supplier", "service_provider"]` at module level,
and both `get_users()` and `get_user_stats()` reference it. Any future PR
that adds a bare role string literal to a `UserRole.role ==`/`.in_(...)`
filter outside of `RoleType` or an explicitly-imported shared constant
should be rejected in review.

This closes the gap because the query side can no longer silently diverge
from the grant side — a typo or renamed role now fails loudly (unknown name)
rather than just matching zero rows.

## Solution

### Immediate Fix
Replaced both `UserRole.role == "seller"` filters with
`UserRole.role.in_(SELLER_ROLES)` where `SELLER_ROLES = ["farmer", "supplier", "service_provider"]`,
and added `.distinct()` to the `get_user_stats()` counts (a user holding more
than one self-listing role would otherwise be double-counted by the join).

### Long-term Fix
Consider migrating `UserRole.role` to a proper FK/enum-backed column (or at
minimum validating against `RoleType` on write) so an invalid role string
can't be persisted or queried in the first place.

## Prevention
- [x] Code changes required (done this session)
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update — note the `RoleType` enum is descriptive
      only, not DB-enforced

## Related Issues
- Found while implementing farmer self-listing support; see
  `reports/tese-marketplace-2026-09-28-farmer-self-listing.md` for the full
  initiative this bug was found during.

## References
- `apps/store-api/app/modules/auth/services/auth_service.py`
- `apps/store-api/app/modules/auth/models/user.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~15 minutes (found during a broader role-model audit)
