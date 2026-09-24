# Child Account Erroneously Locked Out of Subscription

**Date:** 2026-09-24
**Project:** HBEC
**Environment:** Production / Staging
**Severity:** High
**Status:** Resolved

## Summary
Child accounts on a family plan were periodically and erroneously locked out of the system, receiving a 402 Subscription Required error even though their parent had an active subscription. This occurred for children who previously held an individual trial subscription before joining a family plan, or during cache misses when the permission gate fell back to the external payment authority.

## Symptoms
- Child accounts intermittently received 402 Subscription Required responses on paid endpoints (e.g. AI conversational features).
- The parent account was fully paid and active.
- Access randomly degraded from working to lockout for these specific child accounts.

## Environment Details
- **Server/Host:** Student Backend
- **Services Affected:** `apps/accounts/permissions.py`
- **Related Components:** Payments Microservice
- **Time First Observed:** 2026-09-24

## Investigation Steps

### 1. Initial Diagnosis
Looked at how subscription active states are evaluated for a child account in `governing_subscription(user)` inside `STUDENT/hbec_backend/apps/accounts/permissions.py`.

### 2. Root Cause Analysis
- The `governing_subscription` function was evaluating `own = getattr(user, "subscription", None)` *before* checking the `family_membership`. If the child originally signed up individually and their trial expired before they were added to a family, `own` evaluated to `True` (as a local row existed, though expired). Thus, the system returned the child's expired subscription rather than inheriting the parent's active subscription.
- Further down in `HasActiveSubscription`, if the subscription is inactive (or if it's absent entirely), the permission gate falls back to querying the Payments microservice. However, it queried `subscription_is_active(subscription.user_id)` or `subscription_is_active(request.user.id)` which queried the *child's* user ID. The Payments authority correctly responded `False` (because the parent holds the subscription row in Payments, not the child).

### 3. Key Findings
- Evaluating an individual's subscription state before checking for a family membership overrides the family plan logic with stale data.
- Fallback mechanisms for family plans must evaluate the parent's UUID against the authority, not the child's UUID.

## Root Cause
- Incorrect evaluation order in `governing_subscription` prioritized expired individual subscriptions over active family memberships.
- The cache-miss fallback queried the Payments authority using the child's user ID instead of resolving the governing parent user ID.

## Prevention / Rule
**Guardrail:** Ensure that comprehensive permission unit tests (e.g., inside `test_subscription_gate.py`) always explicitly simulate scenarios where a child possesses a stale/expired individual subscription prior to being added to a family plan. 

Adding an isolated test case for `ChildInheritsTheParentPlanTests` that specifically injects an expired individual subscription into the child's account before linking them ensures that any future refactoring of `governing_subscription` cannot unknowingly prioritize the child's stale row over the family plan.

## Solution

### Immediate Fix
- Swapped the logic in `governing_subscription` to evaluate `family_membership` *before* falling back to the user's `own` individual subscription.
- Updated the fallback check in `HasActiveSubscription` so that if a `family_membership` exists, it resolves the `parent_profile.user_id` and uses that to query the Payments authority, instead of indiscriminately passing `request.user.id`.

### Long-term Fix
- Incorporate this edge case into the `test_subscription_gate.py` integration test suite.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
