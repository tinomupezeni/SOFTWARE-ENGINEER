# Payment initiation silently dropped billing_period and promo_code

**Date:** 2026-11-15
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The student backend's payment-initiation proxy (`InitiatePaymentView` in
`STUDENT/hbec_backend/apps/accounts/views.py`) forwarded a payload to the
Payments microservice that never included `billing_period` or `promo_code`,
even though the student frontend always sends both. Every payment therefore
priced at the monthly rate regardless of the plan the student picked, and
every promo code the student entered was silently applied nowhere — the
payment still succeeded, just at full price.

## Symptoms
- User-reported: "promotional codes aren't working" (relayed by the owner;
  no matching entry existed in the live error tracker under any of
  promo/coupon/discount/payments-service filters, and no student feedback
  mentioned it either).
- No 4xx/5xx anywhere, no logged exception on either service — a silent
  logic drop, not a failure.
- A student choosing termly or annual billing would be charged the monthly
  price instead (a second, undetected consequence of the same gap).

## Environment Details
- **Server/Host:** Production (hbca.tech) — found via the `hbec-errors` MCP
  tool and a codebase trace, not reproduced live.
- **Services Affected:** Student Backend (proxy) → Payments microservice
  (price/discount calculation).
- **Related Components:** `STUDENT/Frontend/src/features/subscription/
  services/subscriptionService.ts` (sender), `STUDENT/hbec_backend/apps/
  accounts/views.py::InitiatePaymentView` (proxy, the fault), `PAYMENTS/app/
  api/payments.py::initiate_payment` (consumer of the dropped fields).
- **Time First Observed:** Unknown — the gap has existed since
  `billing_period`/`promo_code` were added to the frontend; nothing in
  the error tracker pins a date because nothing ever errored.

## Investigation Steps

### 1. Initial Diagnosis
Asked via the `hbec-errors` MCP for any logged error matching
promo/coupon/discount/payments across all services and all time — zero
matches, and zero student feedback mentioning it either. This ruled out an
exception-based bug and pointed at a silent logic defect.

### 2. Root Cause Analysis
Grepped the codebase for `promo` across ADMIN/PAYMENTS/STUDENT to find every
place the feature touches:
- `ADMIN/adminBackend/apps/system_settings/views.py` — `promoCodes` stored as
  a JSON-string setting under the `payment` category. Fine.
- `PAYMENTS/app/api/payments.py` — `PaymentInitiateRequest.promo_code`
  (default `""`) and `billing_period` (default `"monthly"`), applied correctly
  when present.
- `STUDENT/Frontend/.../subscriptionService.ts` — `initiatePayment()` sends
  both fields in the POST body to `/api/payments/initiate/`.
- `STUDENT/hbec_backend/apps/accounts/views.py::InitiatePaymentView.post` —
  the proxy that forwards to Payments' `/v1/payments/initiate`. Its `payload`
  dict built only `user_id`, `phone_number`, `method`, `email`, `plan_type`.
  **Neither `billing_period` nor `promo_code` was read from `request.data` or
  included in the forwarded body.**

```bash
grep -rliE "promo[_-]?code|promotional" --include="*.py" --include="*.ts" --include="*.tsx" PAYMENTS ADMIN STUDENT
```

### 3. Key Findings
- The frontend always sent both fields; the proxy never read them.
- Payments' own defaults (`"monthly"`, `""`) silently absorbed the gap —
  the request looked complete and valid from Payments' side, so nothing
  ever raised.
- No existing test in `apps/accounts/tests/test_payments.py` asserted on the
  forwarded request body at all; `test_initiate_payment_ecocash` only
  checked the response shape, never what was sent onward.

## Root Cause
A proxy view manually re-built its outbound payload field-by-field instead of
forwarding (a subset of) the inbound body, and two fields that existed on the
frontend contract from the start were never added to that list. Because the
downstream service treats missing optional fields as "not requested" rather
than erroring, the defect produced correct-looking behavior (a successful
payment) at the wrong price, with no error anywhere to surface it.

## Prevention / Rule
**Guardrail:** A proxy/forwarding endpoint that reshapes a request body into
a new payload for a downstream service needs a contract test asserting on
the *forwarded* body (not just the proxied response) for every field the
caller is documented to send — the same pattern this repo's `service-
signature` golden fixture already applies to auth headers. Added
`test_initiate_payment_forwards_billing_period_and_promo_code` to
`test_payments.py`, which inspects `session.post.call_args` to check the
JSON actually sent to Payments.

This closes the gap because a future field dropped from the payload dict
would now fail a test immediately, rather than surface months later as an
unlogged pricing/discount defect a user has to notice and report by hand.

## Solution

### Immediate Fix
Added the two missing fields to `InitiatePaymentView.post`'s payload dict,
reading both the camelCase and snake_case spellings the frontend/tests use
(matching the existing pattern for `phone_number`/`method`):

```python
"billing_period": request.data.get("billingPeriod")
or request.data.get("billing_period", "monthly"),
"promo_code": request.data.get("promoCode")
or request.data.get("promo_code", ""),
```

### Long-term Fix
Covered by the new regression test (see Prevention / Rule). No data
migration needed — past payments are not retroactively correctable since no
record was kept that a promo code was ever typed; the fix is prospective
only.

## Prevention
- [x] Code changes required (done, `STUDENT/hbec_backend/apps/accounts/
  views.py`)
- [x] Regression test added (`test_payments.py`)
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — consider a Payments-side counter for
  `promo_code` presence vs. applied, to catch a *future* silent-drop
  regression even if a proxy test is skipped
- [ ] Documentation to update — none beyond this entry

## Related Issues
- None filed; found proactively while investigating a user report via the
  `hbec-errors` MCP tool, not an open ticket.

## References
- `STUDENT/hbec_backend/apps/accounts/views.py` (`InitiatePaymentView`)
- `PAYMENTS/app/api/payments.py` (`initiate_payment`, promo-code application)
- `STUDENT/Frontend/src/features/subscription/services/subscriptionService.ts`
- `STUDENT/hbec_backend/apps/accounts/tests/test_payments.py`

---

**Resolved By:** Claude (session with Tino, 2026-11-15)
**Time to Resolution:** Same session — investigation, fix, test, commit.
