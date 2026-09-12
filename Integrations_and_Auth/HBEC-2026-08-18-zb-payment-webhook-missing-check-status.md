# ZB Payment Webhook Had No Defense-in-Depth Status Verification

**Date:** 2026-08-18
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The ZB (Zimbabwe) payment gateway's webhook handler credited a student's subscription the moment it received a `"paid"` claim in the webhook payload, with no independent confirmation against ZB's own API. A forged or replayed webhook carrying `status: "paid"` would have been enough to grant a subscription for free — signature verification on the webhook itself existed, but nothing checked that ZB's systems actually agreed the payment succeeded.

## Symptoms
- Not a live incident — found during a proactive security review of the payments flow.
- The webhook handler (`PAYMENTS/app/api/payments.py`) trusted the payload's `status` field directly for crediting access.

## Environment Details
- **Server/Host:** VPS (production + staging)
- **Services Affected:** `hbec-payments`
- **Related Components:** `PAYMENTS/app/services/zb.py`, `PAYMENTS/app/api/payments.py`
- **Time First Observed:** N/A — proactive review, not a reported incident

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the ZB webhook handler end-to-end: HMAC/signature verification on the inbound webhook was already correct, but the code path that credited a subscription branched directly off the webhook payload's own `status` field.

### 2. Root Cause Analysis
`ZBGateway` had no method to independently query ZB for a transaction's real status — the webhook was the only source of truth, which is exactly what a webhook should never be for a state change with financial consequences.

### 3. Key Findings
- A signature-valid webhook is proof the request came from ZB's infrastructure, not proof the specific claim inside it is still true or was ever true — replay of an old legitimate webhook has the same problem.
- ZB's API supports a status-check-by-reference call that the codebase had never wired up.

## Root Cause
Single-source-of-truth-by-webhook: crediting a paid subscription depended entirely on trusting the webhook body's `status` field, with no server-to-server confirmation against ZB.

## Prevention / Rule
**Guardrail:** A security-review checklist rule, enforced at PR review for any payment integration: no payment/subscription state change may be triggered by a webhook payload field alone — every "paid"-equivalent claim must be independently re-verified via a server-to-server status API call before crediting anything, proven by a synthetic replayed-webhook test (already proposed below).

A signature-valid webhook only proves the request came from the gateway's infrastructure, never that the specific claim inside it is still true — this guardrail is the general form of the fix already applied here.

## Solution

### Immediate Fix
Added `ZBGateway.check_status(order_reference)` and `has_real_credentials()` in `zb.py`, and a `_verify_paid_claim()` helper in `payments.py` wired into `zb_webhook` — a `"paid"` claim now triggers an independent status check against ZB before crediting anything; only claims other than `"paid"` (which don't grant access) skip the extra round-trip.

```python
# PAYMENTS/app/services/zb.py
async def check_status(self, order_reference: str) -> dict: ...
def has_real_credentials(self) -> bool: ...
```

### Long-term Fix
None needed beyond this — the check is now unconditional for the one claim type that matters. Committed as `1d63edb` (`fix(payments): confirm a ZB webhook's paid claim before crediting`).

## Prevention
- [x] Code changes required (committed)
- [ ] Add a synthetic test that replays a stale/forged `"paid"` webhook against a sandboxed ZB double and confirms it's rejected without a matching real status

## References
- `PAYMENTS/app/services/zb.py`, `PAYMENTS/app/api/payments.py`

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~30 minutes (investigation + implementation)
