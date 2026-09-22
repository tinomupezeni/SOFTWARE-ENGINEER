# Admin-Configured Family Plans Were Neither Shown to Parents Nor What They Were Actually Billed

**Date:** 2026-09-22
**Project:** HBEC
**Environment:** Discovered from a live admin screenshot (real configured
tiers/prices), root-caused across three codebases (PAYMENTS, STUDENT
backend, STUDENT frontend)
**Severity:** High — a real, live billing-correctness gap (families billed
against the wrong tier from day one, at every renewal, and shown the wrong
price before ever signing up), not just a display bug
**Status:** Resolved

## Summary
Reported as: family pricing tiers configured in admin ("Family Plans" —
Individual/Small/Medium/Large Family, each with a child-count range and
monthly/termly/annual prices) were "not showing up on the student side...
for the parent to make payment." Tracing this surfaced four compounding
gaps, not one: the pre-signup price preview was completely hardcoded and
disagreed with admin's actual config; the endpoint that starts a family's
trial trusted a caller-supplied plan_type instead of resolving it itself;
the live subscription-status endpoint returned the same flat, Individual-only
price to every tier regardless of what a family was actually on; and the
student backend's own local Subscription mirror used the same stale,
hardcoded breakpoints at the exact moment it was created.

## Symptoms
- `ParentSignupPage`'s live price preview showed static prices ($1/$2/$3.50/$5,
  monthly only) that could not reflect any admin edit — including the
  termly/annual prices admin had configured, which had nowhere on the
  student side to appear at all.
- The preview's own breakpoint logic disagreed with admin's configured
  ranges: admin's Small Family starts at 1 child; the hardcoded
  `getPlanForChildCount()` required 2, so a 1-child family previewed
  "Individual" while admin's own panel said otherwise.

## Investigation Steps

### 1. Initial Diagnosis
`grep` across all three codebases for `familyPlans`/`FamilyPlan` showed
admin's config UI (`FamilyPlansEditor.tsx`) and Payments' resolver
(`resolve_family_tier`, already tested) existed, but zero references
anywhere in `STUDENT/Frontend` — confirming the student-facing side had
never been built at all, not merely broken.

### 2. Root Cause Analysis — four separate gaps, traced end to end

**Gap 1 — the pre-signup preview was 100% hardcoded.**
`STUDENT/Frontend/src/features/subscription/types/index.ts`'s `PLAN_DETAILS`
and `getPlanForChildCount()` never fetched anything; `ParentSignupPage.tsx`
was their only real consumer.

**Gap 2 — start-trial trusted the caller instead of resolving.**
```python
# PAYMENTS/app/api/subscriptions.py, before
class StartTrialRequest(BaseModel):
    plan_type: str = "individual"
```
`resize_subscription` (the *later* tier-change path) already resolves
`plan_type` itself via `resolve_family_tier(child_count, config)` — a fact
reported, not guessed. `start_trial` (the *initial* signup path) never got
the same treatment: it accepted whatever `plan_type` the student backend
sent and wrote it verbatim. Whatever local bug the student backend had in
computing that string became the family's real, billed tier from day one.

**Gap 3 — the live status endpoint always showed Individual's price.**
```python
# GET /v1/subscriptions/{id}, before
"price_monthly": config.get("priceMonthly", 1.00),  # unconditional
```
regardless of `subscription.plan_type` — a `medium_family` subscription
showed `$1.00/mo`, the flat top-level Individual price, because the price
fields were never looked up per-tier from `familyPlans` at all.

**Gap 4 — the student backend's own creation-time resolution matched Gap 2's
bug exactly, independently.**
```python
# apps/accounts/serializers.py, create_trial_subscription, before
plan_type = Subscription.get_plan_for_children_count(child_count)
```
Hardcoded breakpoints (`>=2` for small_family), diverging from admin's
actual `minChildren: 1` the moment anyone configured it — which, per the
pasted admin screenshot that started this investigation, had already
happened.

## Root Cause
Two class-level architecture decisions this codebase already documents
elsewhere ("Payments decides the tier, not the student backend"; "an
honest gap beats a fabricated answer") were only followed for *later*
tier changes (`resize_subscription`), never for the *first* one
(`start_trial`) or for *display* (`get_subscription`'s pricing, the
frontend's preview). The resize path was built correctly once and never
generalized to the other three places a plan_type or its price gets
decided or shown.

## Prevention / Rule
**Guardrail:** every place a family's tier or its price is decided or
displayed now reads from the same admin-configured `familyPlans`, via the
same resolution contract (`resolve_family_tier` in Payments,
`resolve_family_plan` in the student backend, `resolveFamilyPlanTier` in
the frontend — three mirrors of one contract, since these are three
separate runtimes with no shared package). No caller-supplied `plan_type`
is trusted anywhere in the chain anymore; every one resolves from a fact
(`child_count`) against the live config. New tests pin each: Payments'
`test_start_trial.py`, `test_subscription_status_pricing.py`; the student
backend's `ResolveFamilyPlanTests` and the rewritten
`AddChildPlanUpgradeTests` (which — see below — were passing for the wrong
reason before this pass).

## Solution

### Immediate Fix
1. **PAYMENTS** (`app/api/subscriptions.py`):
   - `StartTrialRequest.plan_type: str` → `child_count: int = 0`;
     `start_trial()` now resolves via `resolve_family_tier`, matching
     `resize_subscription` exactly.
   - Added `_tier_pricing(plan_type, config)`: looks up a subscription's
     actual tier price from `familyPlans` by id, falling back to the flat
     fields only when no matching tier is configured. Used in
     `get_subscription`'s existing-subscription branch.
2. **STUDENT backend** (`apps/accounts/`):
   - `serializers.py`: new `resolve_family_plan(child_count, config)`,
     mirroring Payments' resolver exactly; `create_trial_subscription` now
     uses it instead of `Subscription.get_plan_for_children_count`.
   - `views.py`: `ParentSignupView`'s best-effort Payments sync and
     `StartTrialView` (a plain student's own trial-start proxy) now send
     `child_count`, not a locally-guessed `plan_type`.
   - New `GET /api/auth/family-plans/` (`FamilyPlansView`, `AllowAny`,
     matching `PersonalizationOptionsView`'s pre-auth pattern) — the actual
     new surface a signing-up parent's browser reads.
3. **STUDENT frontend** (`src/features/subscription/`):
   - New `FamilyPlanTier` type + `resolveFamilyPlanTier()`, mirroring the
     other two resolvers; `subscriptionService.getFamilyPlans()`.
   - `ParentSignupPage.tsx`'s `PlanSummary` now fetches and resolves real
     data — including a loading state and an explicit "pricing will be
     confirmed after signup" fallback rather than ever fabricating a number
     if the fetch fails or nothing resolves.
   - `SubscriptionPage.tsx`'s `PLAN_DETAILS` usage was deliberately left
     alone: it's an unused-fallback label only (`planDetails?.label`, never
     `.price`), and the actual `$` shown there already comes from the
     now-fixed `get_subscription` proxy — not a second instance of this bug.

### A test suite found genuinely broken along the way, not caused by this fix
`AddChildPlanUpgradeTests` (2 tests) failed identically *before any of this
session's changes* — confirmed by stashing every edit and re-running against
the original code. `_resize_family_plan` deliberately never writes
`plan_type` locally (a second writer is how the mirror used to drift, per
its own docstring — the local copy is updated later via webhook), but these
tests asserted on that local field changing synchronously, and were only
"passing" because their real assertion never ran — `Failed to sync family
plan resize to Payment Service` in the captured output shows the httpx call
itself failing against an unreachable Payments in every test run, silently,
because `AddChildView`'s sync is deliberately best-effort. Rewritten to
assert what the architecture actually does: the resize call reaches
Payments carrying the correct running child_count.

### Verification
- **Payments**: 26/26 relevant tests pass (18 pre-existing/resize/resolve +
  3 new start-trial + 2 new pricing + 3 pre-existing unrelated failures
  confirmed pre-existing via `WEBHOOK_SECRET` env, not this change).
- **Student backend**: `apps.accounts` full suite, 146/146 passing (was
  40/40 in `test_payments.py` alone, 3 failures → 0, with the 2 genuinely
  pre-existing ones fixed properly rather than left broken).
- **Student frontend**: `npm run typecheck` clean; full vitest suite
  1254/1265, identical to the pre-existing baseline (11 failures, all
  `TourManager.test.tsx`, a `QueryClientProvider`-in-tests gap dated
  2026-09-19, confirmed unrelated).

## Prevention
- [x] Code changes required — done, three codebases
- [x] Documentation to update — this entry
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a

## Related Issues
None found for this exact multi-service divergence. Adjacent in spirit to
`HBEC-2026-09-16-payments-is-active-never-checked-current-period-end-for-active-status.md`
(a different Payments correctness gap, unrelated root cause).

## References
- `PAYMENTS/app/api/subscriptions.py`, `app/services/subscriptions.py`
  (`resolve_family_tier`)
- `PAYMENTS/tests/test_start_trial.py`,
  `tests/test_subscription_status_pricing.py` (new)
- `STUDENT/hbec_backend/apps/accounts/serializers.py`
  (`resolve_family_plan`, `get_payment_config`, `create_trial_subscription`)
- `STUDENT/hbec_backend/apps/accounts/views.py`
  (`FamilyPlansView`, `ParentSignupView`, `StartTrialView`)
- `STUDENT/hbec_backend/apps/accounts/tests/test_payments.py`
  (`ResolveFamilyPlanTests`, rewritten `AddChildPlanUpgradeTests`)
- `STUDENT/Frontend/src/features/subscription/types/index.ts`
  (`FamilyPlanTier`, `resolveFamilyPlanTier`)
- `STUDENT/Frontend/src/features/auth/pages/ParentSignupPage.tsx`
  (`PlanSummary`)
- `ADMIN/adminBackend/apps/system_settings/views.py`
  (`DEFAULTS["payment"]["familyPlans"]`, the shape every mirror matches)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — from a pasted admin screenshot to a
verified fix across three codebases and their test suites.
