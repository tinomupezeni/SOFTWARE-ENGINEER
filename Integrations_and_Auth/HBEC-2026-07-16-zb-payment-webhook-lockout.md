# ZB Bank Payment Webhook Lockout Issue

**Date:** 2026-07-16
**Project:** HBEC
**Environment:** Production
**Severity:** Critical
**Status:** Investigating

## Summary
Users who successfully pay via ZB Bank Smile & Pay are not being unlocked in the application. Their payment status remains stuck at `PENDING` in the database, preventing the subscription from activating and keeping the user locked out.

## Symptoms
- User completes payment on ZB Bank portal.
- User is redirected back to the app but remains locked out.
- Payment database record stays at `PENDING` state.
- No webhook activity logged in the `hbec-payments` or `hbec-gateway` containers.

## Environment Details
- **Server/Host:** `hbec-vps`
- **Services Affected:** `hbec-payments`, `hbec-student-backend`
- **Related Components:** ZB Gateway integration
- **Time First Observed:** 2026-07-16

## Investigation Steps

### 1. Initial Diagnosis
Checked container logs for `hbec-payments` and `hbec-gateway` to see if the ZB Bank webhook (`POST /v1/payments/zb/webhook`) was being received and processed or if it was failing due to HMAC signature validation.

### 2. Root Cause Analysis
Found that no webhook requests were reaching the VPS.
Inspected the ZB Gateway initiation code in `PAYMENTS/app/services/zb.py`. Discovered that the ZB Bank callback URL (`resultUrl`) is determined by the `paynowResultUrl` setting in the Admin configuration.

```bash
# Queried the admin backend settings on the VPS
docker exec hbec-payments curl -s http://admin-backend:8000/_internal/settings/payment/
```

### 3. Key Findings
- The `paynowResultUrl` in the Admin configuration was set to `http://localhost:7004/v1/payments/webhook`.
- `zb.py` replaces `webhook` with `zb/webhook`, setting the final callback URL to `http://localhost:7004/v1/payments/zb/webhook`.
- ZB Bank was instructed to send the webhook to `localhost`, which means the callback was never routed to the production VPS.
- Additionally, `zb.py` has a hardcoded fallback to `https://hbec.tech/v1/payments/zb/webhook` if the setting is empty, which appears to be a typo for the actual domain `hbca.tech`.

## Root Cause
The webhook configuration (`paynowResultUrl`) in the production database was incorrectly pointing to `localhost:7004` instead of the public production domain. This caused ZB Bank to fail when attempting to send the background confirmation webhook, leaving payments permanently in the `PENDING` state.

## Solution

### Immediate Fix
(Pending execution) Update the payment settings in the Admin database to point to the correct public production URL (e.g., `https://api.hbca.tech/v1/payments/webhook`).

### Long-term Fix
Update default/fallback URLs in `PAYMENTS/app/services/zb.py` to use `hbca.tech` instead of `hbec.tech` to prevent typos in the future.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- N/A

## References
- None

---

**Resolved By:** Antigravity AI
**Time to Resolution:** 30m
