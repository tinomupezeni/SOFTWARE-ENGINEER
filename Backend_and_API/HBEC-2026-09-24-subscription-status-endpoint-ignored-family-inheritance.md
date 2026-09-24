# Subscription Status Endpoint Ignored Family Inheritance (Second Instance, Same Day)

**Date:** 2026-09-24
**Project:** HBEC
**Environment:** Production / Staging
**Severity:** High — a paying family's child could not see or use their
entitlement; reported live by a tester
**Status:** Resolved

## Summary
A tester activated a paid test subscription for a parent account
(`restk.solutions@gmail.com`) and added a child. Both the parent and child
reported "no subscription" in the product. The parent's own status was
correct once an unrelated duplicate-row bug (this session, same account) was
cleaned up; the child's was not — `/api/subscription/` told the child they
had no subscription at all, even though the parent's plan was active and the
child could actually access paid content. Same underlying problem as
`HBEC-2026-09-24-child-subscription-lockout.md` (fixed same day, by a
different agent) — **a different code path that was never fixed by that
change.**

## Symptoms
- `GET /api/subscription/` as the child returned `isActive: false, status:
  "none"`.
- The same child passed `HasActiveSubscription` (the content-access gate)
  correctly — confirmed directly in a Django shell — so paid AI/content
  endpoints worked while the subscription page told the child they had
  nothing.
- Reported by the user relaying a tester: "the system is saying no
  subscription for both account parent n child."

## Environment Details
- **Server/Host:** Student Backend (staging + production)
- **Services Affected:** `apps/accounts/views.py::SubscriptionView`
- **Related Components:** `apps/accounts/permissions.py` (`HasActiveSubscription`,
  `governing_subscription`), Payments microservice
- **Time First Observed:** 2026-09-24, reported by a tester using a real
  account on production

## Investigation Steps

### 1. Initial Diagnosis
Reproduced directly rather than guessing: generated a real JWT for the
child's own account and called the live endpoint.
```bash
curl https://student.hbca.tech/api/subscription/ -H "Authorization: Bearer <child token>"
# {"isActive": false, "status": "none", ...}
```
Then exercised the actual permission-gate code path in a Django shell
(`HasActiveSubscription().has_permission(FakeRequest(), None)` with
`FakeRequest.user = child`) and got `True` — so the two surfaces disagreed
on the same underlying question for the same account, at the same moment.

### 2. Root Cause Analysis
`SubscriptionView.get()` in `views.py`:
```python
response = client.get(
    f"{settings.PAYMENT_SERVICE_URL}/v1/subscriptions/{request.user.id}",
    ...
)
```
queries Payments with `request.user.id` **unconditionally** — no check for
`family_membership` at all. `HasActiveSubscription`'s fallback (fixed
earlier the same day in `HBEC-2026-09-24-child-subscription-lockout.md`)
does resolve to the parent's id when a `family_membership` exists. The two
call sites answer "who pays for this account" independently, and only one
of them was ever fixed.

### 3. Key Findings
- Fixing a permission *gate* does not fix a *status display* endpoint that
  asks the same authority a different way — they need to share the
  resolution logic, not just agree by convention.
- The child's request to Payments used the child's own id, which Payments
  correctly has no record of (only the parent pays) — this is Payments
  behaving exactly as designed; the bug was entirely in which id
  Student Backend sent it.

## Root Cause
Two independent code paths (`HasActiveSubscription.has_permission`'s
authority fallback and `SubscriptionView.get()`) each re-derived "which user
id does Payments actually know about" instead of sharing one implementation.
The first was fixed in isolation earlier the same day; the second was never
touched because it lives in a different file and wasn't part of that fix's
symptom (a 402 on content endpoints, not a wrong subscription-status page).

## Prevention / Rule
**Guardrail:** `governing_user_id(user)` is now a single function in
`permissions.py`, imported by every place that needs to know which id to
ask Payments about. `HasActiveSubscription`'s fallback and
`SubscriptionView.get()` both call it now — there is no second copy to
independently get wrong. Any future endpoint that reads subscription state
for `request.user` must call this function rather than using
`request.user.id` directly; a code reviewer can grep for
`request.user.id` near `PAYMENT_SERVICE_URL`/`subscription` as a smell.

This closes the actual gap: the earlier fix closed one call site's version
of this bug, not the concept. A shared resolver is what prevents a third
instance the next time someone adds a subscription-aware endpoint.

## Solution

### Immediate Fix
`STUDENT/hbec_backend/apps/accounts/permissions.py`: extracted
`governing_user_id(user)` — returns the parent's id if `family_membership`
resolves to one, else the user's own id. `HasActiveSubscription`'s fallback
branch now calls it instead of its own inline duplicate of the same logic.

`STUDENT/hbec_backend/apps/accounts/views.py`: `SubscriptionView.get()` now
calls `governing_user_id(request.user)` instead of `request.user.id` before
querying Payments.

Added `SubscriptionViewChildInheritanceTests` in `test_payments.py` —
asserts both the response shape (`isActive: True`) and, as the actual
regression guard, which id goes out on the wire
(`assertIn(str(parent.id), called_url)` /
`assertNotIn(str(child.id), called_url)`).

Verified live, end to end, before and after promoting to each environment:
- Staging: child and parent tokens returned byte-identical subscription
  payloads after the fix (same `trialEndsAt`, same `promoCodes`) — before
  the fix they disagreed.
- Production: the actual reported tester account
  (`restk.solutions@gmail.com`'s child) went from `isActive: false` to
  `isActive: true`, matching the parent's Small Family plan, confirmed with
  a real request against the live endpoint post-deploy.

### Long-term Fix
None beyond the shared resolver above — it is the long-term fix.

## Verification
- `pytest apps/accounts/tests/test_payments.py -k SubscriptionView`: 8/8
  passed (6 pre-existing + 2 new), run inside the staging container against
  a real Postgres.
- `pytest apps/accounts/tests/test_subscription_gate.py`: 10/10 passed —
  confirms the `HasActiveSubscription` refactor onto the shared helper
  introduced no regression.
- `ruff check`: clean on all three touched files.
- Live curl against both staging and production, before and after deploy,
  using real tokens for the actual accounts involved (see Solution).

## Prevention
- [x] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none identified; the guardrail here is
  code-shape (shared resolver), not runtime monitoring
- [x] Documentation to update — this entry
- [x] Code changes required — done

## Related Issues
- `HBEC-2026-09-24-child-subscription-lockout.md` — the first instance of
  this same underlying problem, fixed earlier the same day in a different
  code path (`HasActiveSubscription`'s primary branch, `governing_subscription`).
  This entry is the second instance, in `SubscriptionView`, closed by
  extracting the shared `governing_user_id` both fixes should have used
  from the start.

## References
- `STUDENT/hbec_backend/apps/accounts/permissions.py`
- `STUDENT/hbec_backend/apps/accounts/views.py::SubscriptionView`
- `STUDENT/hbec_backend/apps/accounts/tests/test_payments.py::SubscriptionViewChildInheritanceTests`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — diagnosed, fixed, tested, and
confirmed live on both staging and production within roughly an hour
