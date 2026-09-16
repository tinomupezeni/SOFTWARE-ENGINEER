# Expired Subscribers Kept Full Paid Access — Payments' `is_active` Never Checked `current_period_end` for `status="active"`

**Date:** 2026-09-16
**Project:** HBEC
**Environment:** Production
**Severity:** Critical (real revenue-adjacent access-control bug — a lapsed paid subscriber kept unrestricted access to every gated feature indefinitely)
**Status:** Resolved

## Summary
A real user (`mupezeni2001@gmail.com`) reported the dashboard showing
"Active Plan" alongside "0 days left" — a self-contradictory display — and
that they could still use paid features despite the subscription clearly
having lapsed. Diagnosis found this was not a display glitch: the
**Payments microservice's own `is_active` computation** for a subscription
row with `status == "active"` never checked whether `current_period_end`
had actually passed. It only checked the raw status string. The `trial`
branch of the same function correctly checked `trial_ends_at`, but the
`active` branch had no equivalent date check at all — an asymmetric
implementation, not a deliberate design choice.

Because Student Backend's `HasActiveSubscription` permission is
deliberately built to trust the Payments microservice as the authority over
its own local cache (specifically so a lost webhook or stale local row
never wrongly locks a paying student out), this bug did not just mislabel
the dashboard — it actively granted continued access to every
subscription-gated feature for an account that had stopped paying 11 days
earlier.

## Symptoms
- Dashboard: "Active Plan" badge + "0 days left" shown together — a
  combination that should never both be true if `isActive` were correct.
- The student retained working access to features `HasActiveSubscription`
  is supposed to gate.

## Environment Details
- **Server/Host:** Production (`hbca-vps`, `/opt/hbec`)
- **Services Affected:** `PAYMENTS` (root cause), `STUDENT/hbec_backend`
  (`HasActiveSubscription` permission, which trusts Payments' answer;
  `SubscriptionView`/`_shape_subscription_response`, which surfaces the
  same wrong `isActive` to the frontend), `STUDENT/Frontend`
  (`Dashboard.tsx`, purely a symptom — it rendered exactly what the API
  told it)
- **Time First Observed:** 2026-09-16, reported by the user directly

## Investigation Steps

### 1. Initial Diagnosis
Checked the reported account directly in Student Backend's local
`Subscription` cache first:
```
status: expired
current_period_end: 2026-09-05 05:17:51 (11 days in the past)
is_active (property): False
days_remaining (property): 0
```
The local cache was already correct — `expired`, `is_active=False`. This
ruled out the obvious hypothesis (a stale local cache) and pointed at
either the display layer or the live "authority" check `HasActiveSubscription`
falls back to.

### 2. Root Cause Analysis
`SubscriptionView` (`STUDENT/hbec_backend/apps/accounts/views.py`) does not
read the local cache for its response at all — it proxies live to
`PAYMENT_SERVICE_URL/v1/subscriptions/{user_id}` and reshapes that response
(`_shape_subscription_response`). Called that endpoint directly for this
user:
```python
{'is_active': True, 'status': 'active', 'plan_type': 'individual',
 'current_period_end': '2026-09-05T05:17:51.751756',   # 11 days ago
 'trial_ends_at': '2026-08-03T10:44:57.910053'}
```
Payments itself says `is_active: True` for a period that ended 11 days
ago. Read `PAYMENTS/app/api/subscriptions.py`:
```python
is_active = subscription.status == "active" or (
    subscription.status == "trial"
    and subscription.trial_ends_at > datetime.utcnow()
)
```
The `trial` branch checks `trial_ends_at`. The `active` branch does not
check `current_period_end` — it is pure string equality, so once a row's
`status` is set to `"active"` it reports active forever unless and until
some other process explicitly rewrites `status` to something else. Nothing
in this codebase does that automatically — `cancel_subscription` sets it on
an explicit cancel, but a subscription simply running out its paid period
with no renewal has no code path that ever touches `status` again.

### 3. Key Findings
- `_shape_subscription_response`'s `daysRemaining` is computed
  **independently**, straight from the raw `current_period_end` date — it
  has no dependency on the broken `isActive` value, which is exactly why
  the two disagreed in the UI (correct days-left countdown, wrong
  active/expired label) rather than both being wrong the same way.
- `HasActiveSubscription` (`apps/accounts/permissions.py`) already had the
  local cache correctly reading `is_active=False` for this account, and by
  its own design intentionally does **not** stop there — it re-checks
  against Payments (`subscription_is_active()`) before finally refusing,
  specifically to protect a real subscriber from a lost webhook. That
  safety net is what turned Payments' bug into an actual access grant
  rather than just a cosmetic label mismatch:
  ```python
  if subscription.is_active:
      return True
  if subscription_is_active(subscription.user_id):  # asks Payments — returns True (bug)
      return True
  raise SubscriptionRequired()
  ```
- Confirmed via the existing test suite's own fixture style that the
  `trial` branch was written with a real date check from the start — this
  reads as an oversight in the `active` branch specifically, not a
  different design intent for paid vs. trial subscriptions.

## Root Cause
`PAYMENTS/app/api/subscriptions.py`'s `is_active` computation checked
`current_period_end` for neither the "active" branch nor treated a null
`current_period_end` as "not active" — it trusted the raw `status` string
alone. A subscription's `status` field is never automatically rewritten
when its period simply lapses (only an explicit cancel touches it), so
every subscription that ran out without being explicitly cancelled reported
`is_active: True` indefinitely. `HasActiveSubscription`'s deliberate
fail-safe fallback to "ask the authority" then treated that wrong answer as
authoritative, converting a Payments-side logic bug directly into
unrestricted continued access.

## Prevention / Rule
**Guardrail:** `is_active` for a subscription must always be a function of
*both* its status **and** its governing date — never status alone. The fix
extracts a single `_is_subscription_active()` helper used by every endpoint
that reports subscription state, so "active" and "trial" get identical
treatment (status matches **and** the relevant date is still in the
future), and a null governing date reads as not-active rather than
unlimited. This mirrors the equivalent, already-correct property on
Student Backend's own local model
(`STUDENT/hbec_backend/apps/accounts/models.py::Subscription.is_active`) —
the authority and its cache should never have been allowed to compute this
differently in the first place.

This closes the gap because the bug was structural (a branch that could
never notice an elapsed date, by construction) rather than a one-off wrong
value — a single shared function makes "did we check the date" a property
of the whole endpoint, not something each caller has to remember to do
correctly on its own.

## Solution

### Immediate Fix
`PAYMENTS/app/api/subscriptions.py`:
```python
def _is_subscription_active(subscription: Subscription) -> bool:
    if subscription.status == "active":
        return (
            subscription.current_period_end is not None
            and subscription.current_period_end > datetime.utcnow()
        )
    if subscription.status == "trial":
        return (
            subscription.trial_ends_at is not None
            and subscription.trial_ends_at > datetime.utcnow()
        )
    return False
```
Used by both `get_subscription` and `start_trial` (previously each had its
own copy of the same buggy inline expression). Verified live against the
reported account after deploy — see References.

### Long-term Fix
None needed beyond the shared helper above. Separately worth noting (not
fixed here, out of this bug's scope): Payments' own `status` field for a
naturally-lapsed subscription is never rewritten to `"expired"` — nothing
currently needs it to be, since `is_active` is now correctly date-derived
regardless of the status string, but a periodic job that reconciles
`status` itself would make Payments' own admin-facing views/reports less
misleading too.

## Prevention
- [x] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — worth alerting when `is_active=True` is
      returned for a subscription whose `current_period_end` has already
      passed, as a canary for this exact class of regression
- [ ] Documentation to update — note in Payments' README that `status`
      alone is never sufficient to answer "does this subscription grant
      access" — always go through `_is_subscription_active`
- [x] Code changes required — done (see Solution)

## Related Issues
- None yet filed.

## References
- `PAYMENTS/app/api/subscriptions.py` — `_is_subscription_active`,
  `get_subscription`, `start_trial`
- `PAYMENTS/tests/test_api.py` — new regression tests (lapsed active,
  null current_period_end, genuinely active, cancelled)
- `STUDENT/hbec_backend/apps/accounts/permissions.py` —
  `HasActiveSubscription`, `governing_subscription`
- `STUDENT/hbec_backend/apps/accounts/views.py` — `SubscriptionView`,
  `_shape_subscription_response`
- `STUDENT/hbec_backend/apps/accounts/models.py` — `Subscription.is_active`
  (the already-correct local equivalent this was brought in line with)
- `STUDENT/Frontend/src/pages/Dashboard.tsx`,
  `STUDENT/Frontend/src/features/subscription/hooks/useSubscription.ts` —
  where the contradictory "Active Plan / 0 days left" display surfaced

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — root-caused via direct production
API calls to both Student Backend and Payments, fixed and tested within
the hour
