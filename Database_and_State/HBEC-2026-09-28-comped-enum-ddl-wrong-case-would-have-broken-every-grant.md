# A New Postgres Enum Value's Case Would Have Silently Broken Every Write of It

**Date:** 2026-09-28
**Project:** HBEC
**Environment:** Staging (caught before any deploy)
**Severity:** Medium
**Status:** Resolved

## Summary
While building the new admin-grantable comped-subscription feature
(Payments' `SubscriptionStatus.COMPED = "comped"`, a native Postgres enum
with no migration tooling — see `resolve_family_tier`'s docstring), the
first-drafted DDL to widen the enum on the live database was
`ALTER TYPE subscriptionstatus ADD VALUE 'comped';` (lowercase, matching
the Python enum member's `.value`). Querying staging's actual enum labels
before running it showed every existing label stored uppercase
(`TRIAL`, `ACTIVE`, `EXPIRED`, `CANCELLED` — and `PlanType`'s
`INDIVIDUAL`, `SMALL_FAMILY`, ...), confirming SQLAlchemy's `Enum` type
persists a `(str, Enum)` member's **name**, not its `.value`, to the
native Postgres type by default. The lowercase DDL would have added a
label nothing in the ORM ever writes; every attempt to persist
`SubscriptionStatus.COMPED` would have sent `'COMPED'` to a column whose
type only recognized lowercase `'comped'`, failing with "invalid input
value for enum subscriptionstatus" on the very first grant.

## Symptoms
- None yet in production or staging — caught during pre-deploy
  verification, before the corrected DDL was run and before the feature
  branch was pushed.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-postgres-staging` container,
  `hbec_payments` database
- **Services Affected:** `hbec-payments-staging` (would have affected
  production identically once deployed there)
- **Related Components:** `PAYMENTS/app/models.py`'s `SubscriptionStatus`
  enum, `SubscriptionStatus` column (`Mapped[SubscriptionStatus] =
  mapped_column(SQLEnum(SubscriptionStatus), ...)`)
- **Time First Observed:** 2026-09-28, during implementation — not yet
  deployed

## Investigation Steps

### 1. Initial Diagnosis
Before running any DDL against a live database, queried the existing enum
labels to confirm the exact casing/format expected:
```bash
docker exec hbec-postgres-staging psql -U hbec -d hbec_payments \
  -c "SELECT unnest(enum_range(NULL::subscriptionstatus))::text;"
```
Result: `TRIAL`, `ACTIVE`, `EXPIRED`, `CANCELLED` — all uppercase, not the
lowercase `"trial"`/`"active"`/... that `SubscriptionStatus`'s Python
`.value`s actually are.

### 2. Root Cause Analysis
Checked the same for `PlanType` (`INDIVIDUAL`, `SMALL_FAMILY`,
`MEDIUM_FAMILY`, `LARGE_FAMILY`) to confirm this wasn't an isolated quirk
of one column — every native enum in this database follows the same
pattern. Grepped `PAYMENTS/app/*.py` for `values_callable` (the SQLAlchemy
option that would override this to use `.value` instead) — absent
anywhere in this codebase, confirming the default behavior is in force
throughout.

### 3. Key Findings
- SQLAlchemy's `Enum` type, given a Python `Enum` subclass with no
  `values_callable`, persists the member's `.name` as the native Postgres
  label — not `.value`, even for a `(str, Enum)` subclass where the two
  commonly look similar enough to not notice they differ in case.
- Application code that compares `subscription.status == "comped"` still
  works regardless of which casing is stored in the DB — SQLAlchemy
  round-trips the DB label back into the Python enum member, and the
  member's own string identity (via its `str` base) is the lowercase
  `.value`. The DB-column encoding and the Python-side comparison are two
  separate layers; only the DDL itself needs to match the DB layer's
  convention.

## Root Cause
The DDL comment/instruction was written from the Python `.value`
(`"comped"`) without first checking what convention the live enum type
actually uses, which happens to differ from `.value` by case for every
existing label in this table.

## Prevention / Rule
**Guardrail:** Before writing any manual `ALTER TYPE ... ADD VALUE` against
a database with no migration tooling, query the target enum's existing
labels first (`SELECT unnest(enum_range(NULL::the_enum_type))::text;`) and
match their exact casing — never derive the new label from the Python
enum's `.value` alone. This generalizes beyond this one column: any native
Postgres enum backing a SQLAlchemy `(str, Enum)` model in this codebase
follows the same name-not-value convention, so the same check applies to
every future manual widening of one.

## Solution

### Immediate Fix
Corrected `PAYMENTS/app/models.py`'s comment to instruct the uppercase
`ALTER TYPE subscriptionstatus ADD VALUE 'COMPED';` and explain why
(SQLAlchemy's default name-based encoding), then ran that corrected
statement against staging's `hbec_payments` database directly:
```bash
docker exec hbec-postgres-staging psql -U hbec -d hbec_payments \
  -c "ALTER TYPE subscriptionstatus ADD VALUE IF NOT EXISTS 'COMPED';"
```
Verified the new label is present with the same `enum_range` query used
during diagnosis. No application code needed correcting — the Python side
only ever reads/writes via the enum member, never the raw DB label, so
nothing there assumed the wrong casing.

### Long-term Fix
None needed beyond the corrected in-code comment, which now documents the
name-vs-value convention explicitly so the next manual enum widening in
this database doesn't need to rediscover it.

## Prevention
- [x] Configuration changes needed — corrected DDL run against staging
- [ ] Monitoring/alerts to add — none; this fails loudly and immediately
  on the first affected write, not silently
- [x] Documentation to update — `PAYMENTS/app/models.py`'s comment now
  states the convention and the reasoning
- [ ] Code changes required — none; the bug was in a not-yet-run DDL
  instruction, not in application code

## Related Issues
- Found while implementing the admin-grantable comped-subscription
  feature (companion report:
  `reports/HBEC-2026-09-28-admin-grantable-comped-subscription.md`).

## References
- `PAYMENTS/app/models.py` (`SubscriptionStatus`, `PlanType`)
- `PAYMENTS/app/services/subscriptions.py` (`resolve_family_tier`'s
  docstring — the existing note that this service has no migration
  tooling at all)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery, before any deploy
