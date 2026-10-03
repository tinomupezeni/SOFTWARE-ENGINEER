# Paynow Live Mode Prompts Buyers to Log In Instead of Guest Checkout

**Date:** 2026-09-21
**Project:** chemglee-concept-site
**Environment:** Production (Paynow Live integration)
**Severity:** Medium (checkout still completable if the buyer logs in/registers, but adds friction and abandons the guest-checkout UX the storefront advertises)
**Status:** Resolved

## Summary
User reports that Sandbox-mode Paynow checkout skips the login screen (guest
checkout works as intended), but after switching the Shop Manager → Payments
toggle to Live, Paynow's hosted page still prompts buyers to log in instead
of offering guest checkout.

## Symptoms
- Sandbox mode: guest email checkout works, no login prompt on Paynow's page.
- Live mode: Paynow's hosted page asks the buyer to log in, even though the
  storefront advertises guest/card/mobile-money checkout.

## Environment Details
- **Services Affected:** `backend/apps/orders/payments.py` (`start_payment`),
  `backend/apps/orders/paynow.py` (`initiate`, `active_mode`, `_credentials`),
  `backend/apps/orders/models.py` (`PaynowConfig`).
- **Related Components:** Shop Manager admin Payments page
  (`admin/src/routes/payments.tsx`, `AdminPaynowSettingsView` in
  `backend/apps/orders/admin_api.py`).

## Investigation Steps

### 1. Initial Diagnosis
Read `start_payment()` (`backend/apps/orders/payments.py:56-69`) — the
`authemail` sent to Paynow's `initiatetransaction` endpoint is populated in
both modes:
- Live: `order.customer_email or f"{order.reference}@guest.chemgleeonline.com"`
  — always non-blank.
- Sandbox: configured `PaynowConfig.sandbox_email`, else `order.customer_email`,
  else blank (blank is intentional there, to let a developer type an email in
  manually against Paynow's sandbox, which requires authemail to match the
  merchant account).

Since a non-blank `authemail` is passed on every live transaction, the
guest-checkout parameter itself is not the gap — this matches the pattern
that already works correctly in Sandbox.

### 2. Root Cause Analysis
Traced how "live" is determined. `PaynowConfig.load()`
(`backend/apps/orders/models.py:250-253`) does a `get_or_create`, so a config
row always exists, defaulting `mode = "sandbox"` with blank credentials until
someone saves real values from Shop Manager.

`paynow.active_mode()` (`backend/apps/orders/paynow.py:49-54`):
```python
def active_mode() -> str:
    config = _config()
    if config.is_configured:
        return config.mode
    return "live"
```
`is_configured` checks credentials for whatever `config.mode` **currently**
is (`PaynowConfig.active_credentials`, `models.py:255-259`), not both modes.
So the function's fallback to `"live"` fires whenever the *currently selected*
mode has no credentials saved for it — independent of whether `config.mode`
literally says `"sandbox"` or `"live"`, and independent of whether legacy
`PAYNOW_INTEGRATION_ID`/`PAYNOW_INTEGRATION_KEY` env vars (which could be
stale/test credentials from before the admin toggle existed) are actually
what's needed.

`AdminPaynowSettingsView.post()` (`backend/apps/orders/admin_api.py:215-224`)
does block *saving* `mode=LIVE` without both `live_integration_id` and
`live_integration_key` present, which rules out the worst version of this
(an admin flipping to Live with blank Live credentials). But it does not
change the ambiguity in `active_mode()`'s naming — "is_configured → use
`config.mode`, else → `'live'`" reads as "unconfigured defaults to live,"
which is a surprising default direction (normally an unconfigured payment
gateway should fail closed, not silently run live).

### 3. Key Findings
- `authemail` handling is correct and symmetric between modes; not the cause
  of the login prompt by itself.
- Git history (`7d4efd4`, `aa89a37`, `5aa6133`, all 2026-09-18) showed this
  exact "Paynow shows a login screen" symptom had already been diagnosed and
  fixed at the code level — the mode-aware `authemail` bypass now in
  `payments.py:56-69` is that fix, and it's correct.
- Read production state directly (`manage.py shell`, read-only):
  ```
  mode: sandbox
  sandbox_configured: True
  live_configured: True
  is_configured: True
  live_integration_id: '26879'
  sandbox_integration_id: '26879'
  updated_at: 2026-09-18 13:23:35
  updated_by: admin@chemglee.com
  ```
  **`PaynowConfig.mode` was still `"sandbox"`** in production, despite Live
  credentials being filled in. Whoever entered the Live Integration ID/Key on
  2026-09-18 (the same day as the `authemail` fix) never actually saved the
  Mode dropdown as "Live" — or it reverted. `active_mode()`
  (`paynow.py:49-54`) correctly returned `"sandbox"` for this state; the code
  was never the problem.
- Also flagged: `live_integration_id` and `sandbox_integration_id` are
  identically `'26879'`. Paynow normally issues separate IDs per merchant
  profile (test vs live) — worth the admin double-checking that `26879` is
  genuinely the correct Live ID and wasn't copy-pasted from the Sandbox
  field.

## Root Cause
`PaynowConfig.mode` in the production database was `"sandbox"`, not
`"live"` — an admin data-entry gap (Live credentials were saved, but the
Mode toggle itself was not switched to "Live" and persisted). Every checkout
was therefore running against the Sandbox Paynow integration, which is why
buyers saw a test/login-style Paynow page even after Paynow support
confirmed the merchant account itself was live. This was unrelated to the
`active_mode()` fallback logic flagged earlier as a design smell — that
logic behaved correctly given the actual (sandbox) DB state; the fallback
smell remains worth hardening (see Prevention) but was not the cause here.

## Prevention / Rule
**Guardrail:** `active_mode()`/`is_configured()` should fail closed (raise
`PaynowError`, refusing to start a payment) rather than silently defaulting
to `"live"` when the currently-selected mode has no saved credentials and no
legacy env fallback is genuinely intended for this deployment. At minimum,
`GET admin/payments/` should surface a clear warning banner in the Shop
Manager UI whenever `mode` and the credentials actually in effect (DB vs.
legacy env) could diverge.

This closes the "the toggle says Sandbox/Live but the code is actually using
something else" class of confusion this incident's investigation surfaced,
mirroring the same "admin control that doesn't do what it visibly says"
lesson already logged for this repo in
`chemglee-concept-site-2026-09-18-editable-content-registry-silently-diverged-from-storefront.md`.

## Solution

### Immediate Fix
User switched the Mode toggle to "Live" in Shop Manager → Payments and
saved (the audited admin path, `AdminPaynowSettingsView.post()`, rather than
a direct DB write). Confirmed working immediately — `paynow.py` reads
`PaynowConfig` live on every request, no restart needed.

### Long-term Fix
- Tighten `active_mode()`/`_credentials()` to fail closed instead of
  defaulting unconfigured state to `"live"`.
- Surface `is_configured`/`live_configured`/`sandbox_configured` state more
  prominently in the Shop Manager Payments UI so mode and active credentials
  can't silently diverge.

## Prevention
- [x] Configuration changes needed — Mode switched to Live and saved in
      Shop Manager → Payments.
- [ ] Code changes required — fail-closed `active_mode()` fallback; consider
      a UI safeguard in Shop Manager warning if Live credentials are filled
      in but Mode is still Sandbox (the exact state that caused this).
- [ ] Documentation to update — note the mode/credentials divergence risk in
      `PaynowConfig`'s docstring.
- [ ] Double-check `live_integration_id` (`26879`) with Paynow/the admin —
      it's identical to `sandbox_integration_id`, which may or may not be
      correct.

## Related Issues
- `chemglee-concept-site-2026-09-18-editable-content-registry-silently-diverged-from-storefront.md`
  (same "admin surface that looks functional isn't proof it's wired to
  anything real" pattern).

## References
- `backend/apps/orders/payments.py:56-69`
- `backend/apps/orders/paynow.py:49-70`
- `backend/apps/orders/models.py:250-273`
- `backend/apps/orders/admin_api.py:170-228`

---

**Resolved By:** tinomupezeni + Claude Sonnet 5
**Time to Resolution:** Same session
