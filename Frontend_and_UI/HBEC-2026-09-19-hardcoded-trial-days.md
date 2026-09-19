# Trial Configuration Hardcoded and Ignored by Student Frontend

**Date:** 2026-09-19
**Project:** HBEC
**Area:** Frontend and UI

## Issue Description
When the admin disabled the "Enable Free Trial" setting and changed the trial period to 14 days in the System Settings, the student frontend's "No Subscription Found" screen still displayed: "You don't have an active subscription. Start your 7-day free trial today!" and offered a "Start Free Trial" button.

## Root Cause
1. **Frontend Hardcoding:** `SubscriptionPage.tsx` explicitly hardcoded the string `"7-day free trial"` and unconditionally displayed the `Start Free Trial` button whenever a subscription didn't exist or had a status of `"none"`.
2. **Missing Configuration Payload:** The `payments-service` backend and `student-backend` did not pass `trialEnabled` or `trialDays` settings down to the frontend when a user had no existing subscription.

## Resolution
- Modified `PAYMENTS/app/api/subscriptions.py` to retrieve `trialEnabled` and `trialDays` from `config_service` and include them in the `get_subscription` API response, even for users with no subscription.
- Updated `STUDENT/hbec_backend/apps/accounts/views.py` `_shape_subscription_response` to forward these configuration fields under the `data` object to the frontend.
- Updated `Subscription` interface in `STUDENT/Frontend/src/features/subscription/types/index.ts` to include `trialEnabled` and `trialDays`.
- Modified `SubscriptionPage.tsx` to conditionally render the trial message dynamically (e.g., `${trialDays}-day free trial`), and fallback to a "Subscribe Now" prompt if `trialEnabled` is false.

**Resolved By:** Antigravity
