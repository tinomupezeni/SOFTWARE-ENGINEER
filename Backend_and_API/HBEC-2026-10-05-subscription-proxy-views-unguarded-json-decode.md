# Subscription/payment proxy views crashed on an empty-body response from Payments

**Date:** 2026-10-05
**Project:** HBEC
**Environment:** Production (Student Backend)
**Severity:** Low
**Status:** Resolved

## Summary
Four of five Django views that proxy requests to the standalone Payments
microservice called `response.json()` unconditionally, with only
`httpx.RequestError` (connection-level failures) caught — not a
`JSONDecodeError`/`ValueError` from a non-200 response with a genuinely empty
body (e.g. a timeout-triggered 5xx or a proxy error upstream). A single live
occurrence crashed with an uncaught 500 instead of the same graceful "Payment
service unavailable" 502 every other Payments-unreachable case already
returns.

## Symptoms
- `GET /api/subscription/` → `500 JSONDecodeError: Expecting value: line 1
  column 1 (char 0)`, one occurrence, one user, 2026-09-24.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** `hbec-student-backend`
- **Related Components:** `apps/accounts/views.py` — `SubscriptionView`,
  `StartTrialView`, `SubscriptionCancelView`, `PaymentStatusView`
- **Time First Observed:** 2026-09-24, found via `system_error_logs` triage 2026-10-05

## Investigation Steps

### 1. Initial Diagnosis
The error message ("Expecting value: line 1 column 1 (char 0)") is the
standard `json.JSONDecodeError` text for parsing a completely empty string.

### 2. Root Cause Analysis
```python
# SubscriptionView.get, before the fix:
if response.status_code != 200:
    return Response(response.json(), status=response.status_code)  # unguarded
except httpx.RequestError as exc:   # does not catch JSONDecodeError (a ValueError subclass)
```
The repo already has the correct fix pattern next door:
`apps/accounts/payments_client.py::subscription_is_active` wraps the same
kind of call in `except (httpx.RequestError, ValueError)` and treats it as
"unknown" rather than crashing — the author had already recognised this
exact failure class there, but the four proxy views weren't updated to
match. A fifth view, `InitiatePaymentView`, was already safe via a broader
`except Exception` fallback.

## Root Cause
An inconsistently-applied exception-handling pattern: one call site in the
codebase already guarded against an empty/non-JSON Payments response, four
sibling call sites doing the identical kind of call did not.

## Prevention / Rule
**Guardrail:** new tests for each of the three previously-unguarded views
(`SubscriptionView`, `SubscriptionCancelView`, `PaymentStatusView`) mock
`response.json()` raising `ValueError` and assert a `502`, not a `500` —
`test_get_subscription_empty_body_from_payments_is_502_not_500`,
`test_cancel_subscription_empty_body_from_payments_is_502_not_500`,
`test_get_payment_status_empty_body_from_payments_is_502_not_500`.

## Solution

### Immediate Fix
Widened `except httpx.RequestError` to `except (httpx.RequestError,
ValueError)` in `SubscriptionView.get`, `StartTrialView.post`,
`SubscriptionCancelView.post`, and `PaymentStatusView.get` — consistent with
`payments_client.py`'s existing pattern. `InitiatePaymentView` needed no
change (already covered by its own broader `except Exception`).

### Long-term Fix
None needed — this was the complete fix.

## Prevention
- [x] Code change applied
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Test coverage added (`apps/accounts/tests/test_payments.py`,
      new `PaymentStatusViewTests` class — that view had zero prior coverage)

## Related Issues
- Found while triaging the backlog of `system_error_logs` entries surfaced by
  the new `hbec-errors-mcp` tool.

## References
- `STUDENT/hbec_backend/apps/accounts/views.py`
- `STUDENT/hbec_backend/apps/accounts/payments_client.py` (the pre-existing correct pattern this mirrors)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Same session as discovery
