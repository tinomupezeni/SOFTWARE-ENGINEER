# Trial Settings Dropped by Frontend Mapper

**Date:** 2026-09-19
**Project:** HBEC
**Area:** Frontend and UI

## Issue Description
After updating the backend to send `trialEnabled` and `trialDays` to the frontend, the "No Subscription Found" screen still showed the hardcoded "7-day free trial" text and prompt.

## Root Cause
The `subscriptionService.ts` in the student frontend uses an explicit `mapRawSubscription` function to map the incoming JSON payload to the internal `Subscription` type. Because `trialEnabled` and `trialDays` were not explicitly included in the `RawSubscription` interface and the mapper function, they were being silently dropped from the final object. This caused `SubscriptionPage.tsx` to read them as `undefined`, falling back to its `true` and `7` default values.

## Resolution
- Added `trialEnabled` and `trialDays` to the `RawSubscription` interface in `STUDENT/Frontend/src/features/subscription/services/subscriptionService.ts`.
- Updated `mapRawSubscription` to explicitly forward `trialEnabled: data.trialEnabled` and `trialDays: data.trialDays` to the application.

**Resolved By:** Antigravity
