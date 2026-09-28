# Admin-Grantable Comped Subscription Access

**Date:** 2026-09-28
**Project:** HBEC
**Type:** Feature (new capability, cross-service)
**Status:** Completed

## Summary
Admins can now waive payment for a student directly from the Admin
Frontend's student detail page — a distinct `COMPED` subscription status
(never reusing `ACTIVE`), granted either time-boxed (30-day default,
admin-editable) or indefinitely, with every grant recorded in an
append-only audit row (who granted it, why, for how long). Built across
all four services in the chain: Payments (the subscription authority),
Student Backend (local mirror + admin-facing proxy), Admin Backend
(further proxy, admin identity passthrough), Admin Frontend (the actual
UI). Shipped to staging and verified there with real requests through the
full chain, including a full round trip through the live UI's own code
path (Admin Backend → Student Backend → Payments) via direct invocation,
not just isolated unit tests.

## Context / Trigger
Direct user request: "we want to allow an admin to grant access to a
user with a skip subscription kinda thing, waiving subscription payment
for a student." Follow-up direction fixed the design: don't reuse
`ACTIVE`, build "the cleanest approach," include an audit trail, and let
the admin choose time-boxed (default 30 days) or indefinite duration on
each grant.

## Scope
**Included:**
- A new `SubscriptionStatus.COMPED` value and `SubscriptionGrant`
  append-only audit model in Payments (the authority for subscription
  state).
- `grant_subscription()` service function and `POST
  /v1/subscriptions/{id}/grant` endpoint in Payments.
- `_is_subscription_active()`'s new comped branch (null
  `current_period_end` reads as indefinite-and-active, the inverse of
  what null means for `ACTIVE`).
- Student Backend: `Subscription.Status.COMPED`, matching
  `is_active`/`_access_ends_at` property branches (local-cache parity,
  not strictly required for correctness since the authority-fallback
  gate still works without it, but kept in step with every other status
  for consistency).
- Student Backend: `GrantSubscriptionView` (admin-facing internal
  endpoint, proxies to Payments, lets the existing payments webhook sync
  the local mirror — same division `SubscriptionCancelView` already
  relies on).
- Admin Backend: `StudentGrantSubscriptionView`, mirroring
  `StudentConvertToParentView`'s exact `admin_email` passthrough
  convention.
- Admin Frontend: a "Grant Free Access" dialog on the student detail
  page (reason required, duration input defaulting to 30 days, an
  "indefinite" toggle), plus a subscription status section on that page
  (which didn't exist there before at all — subscription display
  previously only lived on the list/table views).
- Test coverage: 5 new Payments tests for the grant endpoint.

**Explicitly excluded:**
- Any UI to *revoke* a grant early or view the grant history — not asked
  for; a grant currently ends by expiring, being re-granted, or the
  student's subscription being separately cancelled through the existing
  cancel path.
- Adding the action to the student list/table view or its row dropdown —
  only the detail page got the action, per the existing precedent that
  not every admin action (e.g. convert-to-parent) needs to exist on both
  surfaces.

## Method
Read the real, current code at every layer before writing anything —
`service_signature.py`, `auth.py`, the full current
`api/subscriptions.py` and `services/subscriptions.py`, the existing
Student Backend `PaymentWebhookView`/`ConvertStudentToParentView`, and the
full Admin Backend `student_management` app — specifically to mirror this
codebase's own proven conventions (the `admin_email`-in-body pattern, the
webhook-syncs-the-mirror division of responsibility, the
read-before-commit rule) rather than inventing new ones. Verified each
layer as it was built (syntax checks, Django system checks, the full
Payments test suite, a frontend typecheck) before moving to staging.

Staging verification used real requests at every hop rather than
"container healthy": direct signed HTTP calls to Payments from inside its
own container, a direct DB query confirming both the subscription row and
its audit row, confirmation the webhook fired and the student backend's
mirror updated, and — critically — invoking the Admin Backend's own
`StudentBackendClient.post(...)` call (the exact code path
`StudentGrantSubscriptionView` uses) via `manage.py shell`, so the
Admin Backend → Student Backend → Payments hop was exercised for real,
not assumed correct because each layer passed in isolation.

## Decisions & Findings
- **Distinct status, not `ACTIVE` reuse** (per explicit user direction):
  reusing `ACTIVE` with a fake period would make a comped account
  indistinguishable from a paying one in revenue reporting and
  renewal-reminder logic, both of which read status directly.
- **Audit trail as its own append-only table**, not a field on
  `Subscription` itself — mirrors this codebase's own established pattern
  (the learner timeline: "append-only, never expires, evidence-agnostic
  ... a correction is a new row"). A grant is history; overwriting it in
  place would lose who granted access once it's later revoked or
  re-granted differently.
- **`admin_email` passed as a plain body field**, not read off the v2
  signature scheme's `X-User-Id`/`ACTOR_HEADER` (which is cryptographically
  bound into the HMAC but which *no* existing endpoint in this codebase
  actually reads for business logic yet). Followed the proven convention
  (`StudentConvertToParentView`'s exact passthrough) rather than being the
  first caller of the unused mechanism.
- **A grant overwrites whatever billing state already exists**, unlike
  `get_or_create_trial_subscription`'s idempotent skip-if-exists — comped
  access exists specifically to override an expired trial or a lapsed
  subscription, so leaving an existing row untouched would defeat the
  feature's purpose.
- **`duration_days=None` means indefinite**, an explicit admin choice
  distinguished from "unspecified" (which the API layer, not the service
  function, defaults to 30) — the Payments-layer function trusts exactly
  what it's given, including "no expiry at all."
- **Payments' no-migration-tooling constraint required a manual DDL** to
  widen the native `subscriptionstatus` Postgres enum. The first-drafted
  DDL used the Python enum's lowercase `.value` (`'comped'`); querying
  staging's actual existing labels first revealed SQLAlchemy persists a
  `(str, Enum)` member's uppercase `.name` by default, not `.value` — the
  wrong-case DDL would have broken every write of the new status. Caught
  before running it; full detail in the companion bug-log entry.
- **Found and fixed an unrelated, real, pre-existing bug** while manually
  verifying the grant/cancel round trip on staging: `cancel_subscription`
  read post-commit ORM attributes for its webhook payload, the exact
  `MissingGreenlet` trap `resize_subscription`'s own comment already
  documents but which `cancel_subscription` was never updated to avoid.
  A live cancellation would 500 and silently never reach the student
  backend's mirror. Fixed and verified against the real staging database
  where it reproduced; full detail in its own bug-log entry.

## Changes Made
- `PAYMENTS/app/models.py` — `SubscriptionStatus.COMPED`,
  `SubscriptionGrant` model.
- `PAYMENTS/app/services/subscriptions.py` — `grant_subscription()`.
- `PAYMENTS/app/api/subscriptions.py` — `GrantRequest` model, `POST
  /{id}/grant`, `_is_subscription_active()`'s comped branch, and the
  unrelated `cancel_subscription` fix described above.
- `PAYMENTS/tests/test_grant_subscription.py` (new),
  `PAYMENTS/tests/test_cancel_subscription.py` (new).
- `STUDENT/hbec_backend/apps/accounts/models.py` — `Status.COMPED`,
  `is_active`/`_access_ends_at` branches.
- `STUDENT/hbec_backend/apps/internal/views.py` + `urls.py` —
  `GrantSubscriptionView`, `users/<id>/grant-subscription/`.
- `ADMIN/adminBackend/apps/student_management/views.py` + `urls.py` —
  `StudentGrantSubscriptionView`, `<id>/grant-subscription/`.
- `ADMIN/adminFrontend/src/features/student-management/` — `api/studentApi.ts`
  (`grantSubscription`), `hooks/index.ts` (`useGrantSubscription`),
  `types/index.ts` (`comped` status, `GrantSubscriptionRequest`),
  `utils/subscriptionDisplay.ts` (comped badge/detail text),
  `pages/StudentDetailPage.tsx` (subscription status display + grant
  dialog).
- Manual staging DDL: `ALTER TYPE subscriptionstatus ADD VALUE
  'COMPED';` against `hbec-postgres-staging`'s `hbec_payments` database.
- Commits: `5cb44f94` (feature), `5b335ff0` (DDL comment correction),
  `68d53606` (cancel_subscription fix). Pushed to `master`.

## Verification
- Payments: full test suite (71 tests after the additions, all passing) —
  5 new for grant, 3 new for cancel.
- `python3 -m py_compile` across every touched Python file; Django
  `manage.py check` clean on both Student Backend and Admin Backend.
- Frontend: `npm run typecheck` (`tsc -b --noEmit`) — zero errors under
  full strict mode.
- Staging (real requests, not container-health-only):
  - Direct signed `POST /v1/subscriptions/{id}/grant` against
    `hbec-payments-staging` — both time-boxed and indefinite paths,
    confirmed correct `is_active`/`current_period_end` in the response
    and the `subscription_grants` audit row in the database.
  - Confirmed the payments→student-backend webhook fires and the local
    `Subscription` mirror updates to `comped` for a real staging student
    account.
  - Confirmed the Admin Backend's exact `StudentBackendClient.post(...)`
    call succeeds end-to-end (Admin Backend → Student Backend →
    Payments), via direct invocation through `manage.py shell` — the same
    code path `StudentGrantSubscriptionView` runs.
  - Confirmed `cancel_subscription`'s fix against the real
    asyncpg/pgbouncer stack where the bug originally reproduced, restoring
    the test account's state afterward.
  - GitHub Actions could not run for this push (account-wide billing
    block — see Follow-ups), so this staging deploy was done manually
    (`git pull` + `docker compose build`/`up --force-recreate` on the VPS),
    matching this session's established manual-deploy fallback.

## Follow-ups / Deferred
- **GitHub Actions is blocked account-wide** ("recent account payments
  have failed or your spending limit needs to be increased"), affecting
  every workflow on every branch, not just this push — needs the account
  owner to resolve billing before CI/CD resumes automatically deploying
  on push to `master`/`main`.
- **Production still runs the unfixed `cancel_subscription`** until
  Payments is next deployed there — this feature's own comped-grant code
  hasn't shipped to production yet either, both pending the usual
  human-approved production promotion.
- No UI exists yet to revoke a grant early or view grant history — out of
  scope for this request, not attempted.

## References
- `Database_and_State/HBEC-2026-09-28-comped-enum-ddl-wrong-case-would-have-broken-every-grant.md`
- `Backend_and_API/HBEC-2026-09-28-cancel-subscription-500-after-successful-cancel.md`

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session
