# Paynow Forcing Login Screen on Checkout

**Date:** 2026-09-18
**Project:** Chemglee Concept Site
**Environment:** Production / Development
**Severity:** Medium
**Status:** Resolved

## Summary
When users attempted to check out, they were redirected to a Paynow screen saying "Please login using Guest Payment or Member Login to access this page" instead of being shown the payment methods directly. This created unnecessary friction in the checkout process, especially since the storefront only collected Name and Phone Number.

## Symptoms
- Users redirected to Paynow login/email entry screen.
- The business wanted users to go straight to Ecocash/OneMoney/Visa selection without being prompted for an email or login.

## Environment Details
- **Server/Host:** All environments
- **Services Affected:** `backend/apps/orders/payments.py`
- **Related Components:** Paynow Integration

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the `start_payment` function in `payments.py` and the frontend `cart.tsx`.

### 2. Root Cause Analysis
Checked the Paynow API documentation and behavior regarding the `authemail` field. If `authemail` is omitted or empty, Paynow forces the user to manually enter an email on a preliminary screen. Since `cart.tsx` does not collect an email address, `order.customer_email` was empty, causing `authemail` to be passed as `""`.

### 3. Key Findings
- Paynow requires an email address to associate with the transaction.
- If a valid email is passed to `authemail` that does *not* belong to a registered Paynow user, Paynow skips the login screen and proceeds directly to payment method selection (Guest Checkout).
- If the email belongs to a registered user, they are prompted for a password.

## Root Cause
The `authemail` field in the Paynow initiation request was empty because the checkout form was designed for speed and only collected phone numbers, causing Paynow to prompt the user for an email address.

## Prevention / Rule
**Guardrail:** Always generate and pass a unique dummy email to third-party payment gateways that require an email for guest checkout when the domain business rules dictate that emails are not collected from the customer.

This prevents the gateway from blocking the user flow with account creation/login prompts.

## Solution

### Immediate Fix
Updated `backend/apps/orders/payments.py` to auto-generate a unique dummy email (`f"{order.reference}@guest.chemgleeonline.com"`) if `order.customer_email` is empty **and Paynow is in live mode**. In Sandbox/Test mode, Paynow restricts `authemail` to exactly match the registered merchant email, so the bypass is disabled in test mode to prevent transaction rejections.

```python
# backend/apps/orders/payments.py
if paynow.active_mode() == "live":
    auth_email = order.customer_email or f"{order.reference}@guest.chemgleeonline.com"
else:
    auth_email = order.customer_email or ""
```

### Long-term Fix
No further action needed; the dummy email approach handles all guest checkout flows elegantly without spamming the merchant's real inbox.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
None

## References
- Paynow API Documentation

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
