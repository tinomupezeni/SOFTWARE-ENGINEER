# Parent Dashboard Billing Accuracy & Plan Labels Fix

**Date:** 2026-09-23
**Project:** HBEC
**Type:** Feature Fix / UI Improvement
**Status:** Completed

## Summary
Fixed a hardcoded plan label bug in the subscription system that was causing UI discrepancies when custom tiers were configured, and improved the parent dashboard to surface billing information directly rather than requiring a click-through. Also added clear messaging about when child count changes affect the bill.

## Context / Trigger
The user asked: "is the money for child under parent subscribtions handled well, the plans the subscription plan should appear on the parent dashboard for how much they are supposed to pay"
This prompted an investigation that uncovered an existing hardcoded enum label bug and two UX gaps on the parent dashboard.

## Scope
Included:
- Fixing the source-of-truth plan label to flow from admin's `familyPlans` configuration through the Payments service to the Student frontend.
- Adding the live plan label and price to the parent dashboard.
- Adding explanatory text regarding when tier price changes take effect.

Excluded:
- Creating a new dedicated test file for the `ParentDashboardPage.tsx` changes (deferred due to scope and matching existing project conventions).

## Method
- Modified the Payments service (`PAYMENTS/app/api/subscriptions.py`) to resolve the correct tier `label` directly from configuration.
- Updated the Student backend (`STUDENT/hbec_backend/apps/accounts/views.py`) to prefer this dynamic label over the old `Subscription.PlanType` Django enum fallback.
- Updated `SubscriptionPage.tsx` on the frontend to display the dynamic label and added messaging about the billing cycle.
- Updated `ParentDashboardPage.tsx` to query and invalidate subscription status so that it displays accurate real-time data immediately after changes (e.g., adding a child).

## Decisions & Findings
- **Bug:** `planLabel` was previously hardcoded alongside the price in an enum (e.g. `Small Family ($2/mo, 2-3 kids)`). When admin updated prices or added custom tiers, the UI would still show the old hardcoded string and misaligned prices.
- **Decision:** Let `Payments` own the tier label since it already owns the price, falling back to legacy strings only if no matching config is found.
- **UX Gaps:** The parent dashboard only had a static "Manage Billing" card. It now dynamically shows the plan, price, and renewal date. A message was added in `SubscriptionPage` to clarify that a child-count change takes effect at the *next* renewal cycle to avoid billing confusion.

## Changes Made
- `PAYMENTS/app/api/subscriptions.py` & tests
- `STUDENT/hbec_backend/apps/accounts/views.py` & tests
- `STUDENT/Frontend/src/features/subscription/pages/SubscriptionPage.tsx`
- `STUDENT/Frontend/src/features/subscription/types/index.ts`
- `STUDENT/Frontend/src/features/subscription/index.ts`
- `STUDENT/Frontend/src/features/parent/pages/ParentDashboardPage.tsx`

## Verification
- `npm run typecheck` passed cleanly for the frontend.
- Full backend pytest suite passed (baseline pre-existing failures only).
- Frontend tests passed (baseline pre-existing failures only).
- Staging deployed and smoke-tested live using Django shell and `APIClient` to verify the JSON payload contains the dynamic label.

## Follow-ups / Deferred
- Adding a dedicated Jest test suite for `ParentDashboardPage.tsx` is deferred.

## References
- `HANDOFF-subscription-label-fix.md`

---

**Completed By:** Antigravity (Gemini CLI)
**Duration:** 2 sessions (mid-session handoff)
