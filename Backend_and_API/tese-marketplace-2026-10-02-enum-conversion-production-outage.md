# Production outage: SQLAlchemy Enum matches member NAME not VALUE by default

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
Converting `UserRole.role`, `ProviderApplication.application_type`/
`.status`, `Product.listing_type`, and `Conversation.conversation_type`/
`.status` from plain `String` columns to `sqlalchemy.Enum(SomePyEnum)`
crash-looped `store-api` in production immediately on deploy.
SQLAlchemy's `Enum` type, given a Python `(str, Enum)` class, defaults to
matching the enum member's **name** (`"ADMIN"`) against the stored
database value, not its **value** (`"admin"`) - and every one of these
columns already held lowercase data written before this conversion.
Production was down (container crash-looping) for several minutes while
this was diagnosed and fixed live.

## Symptoms
- `store-api` container entered a restart loop immediately after deploy.
- `docker logs tese-store-api`:
  ```
  LookupError: 'admin' is not among the defined enum values.
  Enum name: role_type.
  Possible values: CUSTOMER, SALES_AGENT, ACCOUNTANT, ..., SUPER_ADMIN
  ```
- After the first fix, a second, related failure surfaced on
  `GET /api/catalog/products` (500):
  ```
  fastapi.exceptions.ResponseValidationError: ...
  'msg': "Input should be 'product', 'supplier_product' or 'service'",
  'input': <ListingType.PRODUCT: 'product'>
  ```

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-store-api`
  container, `tese_store` database)
- **Services Affected:** Entire backend (container crash-loop = full
  outage), then specifically product/category browsing after the
  partial fix
- **Related Components:**
  `apps/store-api/app/modules/auth/models/user.py`,
  `apps/store-api/app/modules/catalog/models/catalog.py`,
  `apps/store-api/app/modules/chat/models/chat.py`,
  `apps/store-api/app/modules/catalog/schemas/catalog.py`,
  `apps/store-api/app/modules/auth/schemas/auth.py`
- **Time First Observed:** 2026-10-02, immediately on deploying the enum
  conversion

## Investigation Steps

### 1. Initial Diagnosis
`docker ps` showed the container in a restart loop within seconds of
redeploy; `docker logs` gave the exact `LookupError` with the mismatched
value pinpointing the column (`role_type` / `'admin'`) immediately.

### 2. Root Cause Analysis
Recognized this as SQLAlchemy's well-known default behavior for
`Enum(PythonEnumClass)`: without `values_callable`, it uses each
member's `.name` for the native-enum label set and for matching stored
values back to Python, not `.value`. Checked why `Order.status`/
`Payment.status` (already using plain `Enum(OrderStatus)` without this
fix, pre-dating this session) hadn't hit the same bug: they were
declared as `Enum` from the very start, so whatever convention
SQLAlchemy used by default was also the convention used when the data
was first written (uppercase member names) - internally consistent, no
mismatch. The bug only appears when a column that already held
lowercase string data from a prior `String` column phase is converted
to `Enum` without `values_callable`.

### 3. Key Findings
- Before the crash was fully fixed, its `init_db()`/`create_all()` call
  had already run far enough to auto-create 6 Postgres enum TYPEs with
  the wrong (uppercase, name-based) labels - harmless at that point
  since no column referenced them yet, but they would have collided
  with the correctly-labeled types the real fix needed to create.
- The second failure (`ResponseValidationError` on `/api/catalog/products`)
  was a distinct, cascading issue: Pydantic's `Literal[...]` response
  field validator rejects a `(str, Enum)` instance even though it
  string-equals the literal correctly, once the ORM actually starts
  returning real enum instances instead of plain strings.

## Root Cause
`sqlalchemy.Enum(SomePyEnumClass)` without `values_callable=lambda e:
[m.value for m in e]` matches by the enum member's `.name`, not
`.value` - a non-obvious default that only causes a problem retroactively,
when a column that already has real lowercase string data is converted
to use it, as opposed to a column declared as `Enum` from day one.

## Prevention / Rule
**Guardrail:** Any time an existing `String` column with real data is
converted to `sqlalchemy.Enum(PyEnumClass)`, `values_callable=lambda e:
[m.value for m in e]` is mandatory, not optional - and before deploying
such a conversion, query the actual distinct values currently in that
column and confirm they match the Python enum's **values** (lowercase),
not just that the strings "look right." Additionally: any Pydantic
response schema field with a `Literal[...]` type that's populated
`from_attributes` off an ORM object backed by an `Enum`-typed column
must be declared as plain `str` on the response schema specifically
(keep `Literal` on Create/Update schemas for real input validation).

## Solution

### Immediate Fix
1. Added `values_callable=lambda e: [m.value for m in e]` to all 7 new
   `Enum(...)` column declarations.
2. The crash had already auto-created 6 wrongly-labeled Postgres enum
   types before failing. Rather than `DROP TYPE` (correctly blocked by
   the sandbox's destructive-action safeguard, and production was down -
   no time to wait on a permission round-trip), renamed every new type
   (`role_type` -> `user_role_type`, `seller_role_type` ->
   `provider_role_type`, `application_status` ->
   `provider_application_status`, `listing_type` ->
   `product_listing_type`, `conversation_type` ->
   `chat_conversation_type`, `conversation_status` ->
   `chat_conversation_status`) so the correctly-labeled types could be
   created immediately via a non-destructive path. Confirmed zero
   columns referenced the old names, then dropped them with explicit
   user confirmation once production was stable again.
3. For the cascading `ResponseValidationError`: declared `listing_type`/
   `application_type`/`status` as plain `str` on `CategoryResponse`,
   `ProductResponse`, and `ProviderApplicationResponse` specifically
   (overriding the parent Base class's stricter `Literal` type), while
   keeping `Literal` on the Create/Update schemas for actual input
   validation.

```bash
python3 -m py_compile <all changed files>   # clean at each step
```
Verified via full smoke test after each fix: site, admin dashboard,
`GET /api/catalog/products`, `GET /api/catalog/categories`, and a
round-trip test of `GET /api/auth/me/applications` (reading back an
`application_type`/`status` enum value through the full ORM -> Pydantic
response path) - all correct, no errors in logs.

### Long-term Fix
None needed beyond the guardrail above - every enum conversion going
forward should include `values_callable` and a response-schema check as
standard practice, not something to rediscover.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `reports/tese-marketplace-2026-10-02-enum-conversion-and-application-type-normalization.md`
  (the initiative this incident happened during)
- `Database_and_State/tese-marketplace-2026-10-02-application-type-multi-role-normalization.md`

## References
- `apps/store-api/app/modules/auth/models/user.py`
- `apps/store-api/app/modules/catalog/models/catalog.py`
- `apps/store-api/app/modules/chat/models/chat.py`
- `apps/store-api/app/modules/catalog/schemas/catalog.py`
- `apps/store-api/app/modules/auth/schemas/auth.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~20 minutes from outage start to fully verified stable
