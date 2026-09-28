# cancel_subscription 500'd After the Cancel Already Succeeded — Webhook Never Fired

**Date:** 2026-09-28
**Project:** HBEC
**Environment:** Staging (reproduced live; same code path runs in production)
**Severity:** High
**Status:** Resolved

## Summary
While manually verifying the new admin-grantable comped-subscription
feature on staging (real HTTP requests against Payments, per this
codebase's pre-deploy verification discipline), restoring a test
subscription via `POST /v1/subscriptions/{id}/cancel` returned a 500, even
though the subscription's `status` column had already been updated to
`cancelled` in the database. `cancel_subscription`
(`PAYMENTS/app/api/subscriptions.py`) read
`subscription.status`/`subscription.plan_type`/
`subscription.current_period_end` *after* `await db.commit()`, which
expires every ORM attribute by default (`expire_on_commit=True`, the
session's default). Accessing them afterward triggers an implicit
lazy-refresh from the database outside an awaited/greenlet context, which
SQLAlchemy's async engine cannot do and raises `MissingGreenlet`. The
crash happened *before* the webhook broadcast that syncs the student
backend's local `Subscription` mirror, so every real cancellation hitting
this path silently never reached that mirror.

## Symptoms
- `POST /v1/subscriptions/{id}/cancel` returns 500, but the subscription
  is already cancelled in the database (visible via `GET
  /v1/subscriptions/{id}` immediately after).
- The student backend's local `Subscription.status` mirror stays `active`
  indefinitely for anyone who cancels through this path, since the
  webhook that updates it is never reached.
- `HasActiveSubscription`'s authority-fallback (`subscription_is_active()`
  in Student Backend's `payments_client.py`) would eventually catch a
  stale mirror on its own, at the cost of an extra network round-trip on
  every gated request — the mirror desync is masked, not harmless.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-payments-staging` (asyncpg driver via
  `main-pgbouncer`, transaction pooling)
- **Services Affected:** Payments (`hbec-payments-staging` /
  `hbec-payments` in production — same code, unpatched until this fix
  ships there too), Student Backend's local subscription mirror
  (downstream effect)
- **Time First Observed:** 2026-09-28, while verifying the new comped-
  grant feature's `/grant` → `/cancel` round trip on a real staging
  student account

## Investigation Steps

### 1. Initial Diagnosis
`POST /cancel` against a real staging student
(`01a0e70d-fd2b-7765-8e78-2e3aa2777ddc`) returned 500. A follow-up `GET`
on the same subscription showed `"status": "cancelled"` — the write had
already landed, so the 500 was happening in whatever ran *after* the
commit, not in the cancel logic itself.

### 2. Root Cause Analysis
```bash
docker logs hbec-payments-staging --since 30s
```
showed the real traceback ending in
`sqlalchemy.exc.MissingGreenlet: greenlet_spawn has not been called; can't
call await_() here.` — raised from SQLAlchemy's asyncpg connection-pool
ping path, triggered by an attribute access that needed to re-fetch from
the database.

Reading `cancel_subscription`'s source showed exactly this: it commits,
then immediately reads `subscription.status`, `subscription.plan_type`,
and `subscription.current_period_end` to build the webhook payload.
`resize_subscription`, in the same file, already carries a comment
documenting this precise trap (`db.commit()` expiring every attribute,
touching them afterward triggering an implicit lazy-refresh outside an
awaited context) and reads everything it needs *before* committing to
avoid it. `cancel_subscription` predates that fix and was never brought
in line with it.

### 3. Key Findings
- No existing test exercised `POST /cancel` at all —
  `tests/test_api.py::test_cancelled_status_is_never_active_regardless_of_dates`
  only checks the *read* side of an already-cancelled row, never posts to
  the cancel endpoint itself. The bug had no test surface to be caught by.
- The in-memory SQLite test backend (`tests/conftest.py`) does not
  reproduce this crash even after the fact — a regression test against it
  passes both before and after the fix in terms of not raising, so this
  class of bug is specifically an asyncpg/real-Postgres behavior that
  SQLite-backed tests cannot catch. The new test still locks in correct
  values and response shape, but the crash itself was only ever visible
  against real Postgres.

## Root Cause
`cancel_subscription` read ORM attributes for its webhook payload after
`db.commit()` had already expired them, instead of capturing the values
it needed beforehand — the exact anti-pattern `resize_subscription`
already documents and avoids in the same file.

## Prevention / Rule
**Guardrail:** Any endpoint in this file that both commits a change and
needs to read from the just-committed row afterward (for a response body
or a webhook payload) must capture those values into local variables
*before* `await db.commit()`, per the pattern `resize_subscription`
already established. Since SQLite-backed tests cannot reproduce the
crash, the actual guardrail is procedural: any new or touched write
endpoint here must be manually exercised with a real request against a
real Postgres-backed environment (staging) before being called verified —
not just passed against the SQLite suite.

## Solution

### Immediate Fix
`PAYMENTS/app/api/subscriptions.py`'s `cancel_subscription`: capture
`plan_type_value` and `period_end_value` into local variables before
`subscription.status = "cancelled"` / `await db.commit()`, then pass those
locals (plus the literal `"cancelled"`, already known without needing to
re-read it) into `notify_subscription_update(...)`. Rebuilt and
force-recreated `hbec-payments-staging`; re-ran the exact failing call
against the same real student account and confirmed `200 {"success":
true, "message": "Subscription cancelled"}`, the webhook firing
(`subscription_updated_via_webhook` in the student backend's logs), and
the student backend's local mirror updating to `cancelled`.

### Long-term Fix
None beyond the fix itself — this was the only remaining unfixed instance
of the pattern in this file (`start_trial` and `grant_subscription` both
already read-then-write in the correct order; `resize_subscription`
already had its own fix).

## Prevention
- [x] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none; this fails loudly (500) and
  immediately on the next real cancellation once deployed
- [x] Documentation to update — inline comment added at the fix site,
  naming the same trap `resize_subscription`'s comment already names
- [x] Code changes required — done, staging verified; production still
  needs this same rebuild/redeploy the next time Payments ships there

## Related Issues
- Found while implementing and verifying the admin-grantable
  comped-subscription feature (companion report:
  `reports/HBEC-2026-09-28-admin-grantable-comped-subscription.md`).
- Same general class of bug as `resize_subscription`'s already-documented
  fix in the same file — this entry exists because that fix was never
  applied to `cancel_subscription` too.

## References
- `PAYMENTS/app/api/subscriptions.py` (`cancel_subscription`,
  `resize_subscription`)
- `PAYMENTS/tests/test_cancel_subscription.py` (new — the regression test
  this endpoint never had)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery; staging verified,
production still needs the next Payments deploy to pick it up
