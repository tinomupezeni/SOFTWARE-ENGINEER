# SubscriptionPage trapped a lapsed subscriber between "Renew" and a forced logout

**Date:** 2026-10-26
**Project:** HBEC
**Environment:** Production (reported by the user from their own account)
**Severity:** Medium
**Status:** Resolved

## Summary
A student whose subscription period had ended (reported: plan "Individual
($1/mo)", status badge still "Active", "0 days remaining", period ended
October 19, 2026) landed on `SubscriptionPage` with only two options:
"Renew Subscription" and "Back" — and "Back", in this exact state, logs the
student out entirely rather than navigating anywhere. There was no way to
simply continue to the dashboard, even though the dashboard shell itself
has never required an active subscription (only the individual content
pillars do).

## Symptoms
- User-reported: "we supposed to have a proceed to dashboard for users who
  are locked out like here" — a direct report with a screenshot of the
  exact screen, plus an explicit expectation ("thought we already had this
  in place") that this escape hatch already existed.
- The subscription status badge reads "Active" while the page's computed
  `isActive` is `false` (the period has run out: 0 days remaining), because
  `status` and `isActive` are independent fields and a lapsed-but-not-yet-
  server-flipped-to-"expired" subscription can show this combination.
- Clicking "Back" in this state calls `logout()` and redirects to `/login`
  — an unrelated existing behavior that becomes the only other option once
  "Renew Subscription" is the sole forward path.

## Environment Details
- **Server/Host:** `STUDENT/Frontend` (React web app), served from both
  colors in production.
- **Services Affected:** Student-facing subscription UI only; no backend
  change needed.
- **Related Components:**
  `STUDENT/Frontend/src/features/subscription/pages/SubscriptionPage.tsx`,
  `STUDENT/Frontend/src/features/subscription/components/SubscriptionGate.tsx`.
- **Time First Observed:** 2026-10-26, reported by the user directly.

## Investigation Steps

### 1. Initial Diagnosis
Located the exact screen by grepping for the reported UI strings ("Days
Remaining", "Current Period Ends", "Renew Subscription") — a single match,
`SubscriptionPage.tsx`.

### 2. Root Cause Analysis
Read the page's render logic for the branch shown when a subscription
object exists (as opposed to the earlier `!subscription || status ===
'none'` branch, which already has a "Go to Dashboard" button with a
comment explaining exactly why it's needed). The action-buttons block for
an existing subscription had:
- `subscription.isActive && <Continue to Dashboard>` — only for a
  genuinely active subscription.
- `needsPayment || status === 'trial' ? <Subscribe/Upgrade> : <Renew
  Subscription>` — `needsPayment` is `status === 'expired' || 'cancelled'`,
  which is `false` for a subscription still marked "active" server-side
  even though its period has ended, so this fell to "Renew Subscription".
- A `Back` button that logs the student out when `!subscription.isActive`.

Cross-checked the architecture: `App.tsx`'s route table wraps every content
pillar (`/exam-practice`, `/revision`, `/projects`, `/guided-learning`,
`/interactive`, ...) in `SubscriptionGate`, but deliberately does **not**
wrap `/` or `/dashboard` — confirmed in `SubscriptionGate.tsx`'s own
docstring ("Redirects to /subscription when the user has no active
subscription/trial... Do not wrap /subscription...") and the route
definitions themselves. The dashboard shell has never required an active
subscription; only the content pillars individually gate themselves. This
is the exact reasoning already written into the no-subscription branch's
own "Go to Dashboard" button — it just was never carried into the
subscription-exists branch below it.

### 3. Key Findings
- The gap is specifically the combination `status !== 'expired'/'cancelled'`
  (so the badge still reads something other than clearly-expired) **and**
  `isActive === false` (so neither forward-progress button renders) — a
  real, reachable production state, not a hypothetical.
- The existing "Back → logout" behavior for an inactive subscriber appears
  to predate the dashboard being reachable without a subscription, and
  nothing in the current codebase explains why it should still log out
  rather than navigate — left untouched here since it wasn't the reported
  symptom and changing it needs its own reasoning, but it's unusual and
  worth separate scrutiny later (see Follow-ups).

## Root Cause
The "an account always has somewhere to go that isn't a paywall" pattern
was implemented once (the no-subscription-found card) but never carried
into the sibling branch for an existing-but-not-currently-active
subscription, which is the far more common real-world case (everyone who
ever had a subscription passes through this state at every renewal
boundary).

## Prevention / Rule
**Guardrail:** Any screen gating forward progress on a computed boolean
(here, `isActive`) must independently guarantee at least one non-paywall
exit — specifically, a direct link to the dashboard shell — for every
value that boolean can take, not just the happy path. A code-review
checklist item for subscription/paywall screens: "does every branch of
this component's render logic that depends on subscription state have a
way to reach the dashboard without paying?"

This closes the specific gap because the two conditions that produced the
dead end (`needsPayment` false, `isActive` false) are not exhaustive of
"subscription exists" — they leave exactly the gap this bug lived in, and
a guard asking "where does a user with isActive=false land" would have
caught it at review time.

## Solution

### Immediate Fix
Added a "Go to Dashboard" button to the existing-subscription branch,
shown only when `!subscription.isActive` (so it never duplicates the
"Continue to Dashboard" button already shown when active), with the same
copy/placement pattern as the sibling button in the no-subscription-found
branch. 4 new tests cover: shown when active-status-but-isActive-false,
shown when genuinely expired, hidden when genuinely active, and confirms
it never triggers the logout path.

### Long-term Fix
None needed beyond the guardrail above — this was a one-screen gap, not a
systemic issue with the gating architecture (which is otherwise correctly
designed: dashboard ungated, pillars individually gated).

## Prevention
- [x] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — N/A, a UI-only dead end.
- [ ] Documentation to update — N/A.
- [x] Code changes required — done, see Solution.

## Related Issues
- None directly, but see Follow-ups on the "Back" button's logout behavior.

## Follow-ups / Deferred
- `SubscriptionPage`'s "Back" button logs an inactive subscriber out
  entirely rather than navigating. Not changed here (not the reported
  symptom, and changing it needs someone to confirm whether that logout
  was ever intentional for a reason not visible in the current code) — now
  that "Go to Dashboard" exists as the correct forward path, this behavior
  is less likely to trap anyone, but it's still worth a second look.

## References
- `STUDENT/Frontend/src/features/subscription/pages/SubscriptionPage.tsx`
- `STUDENT/Frontend/src/features/subscription/components/SubscriptionGate.tsx`
- `STUDENT/Frontend/src/App.tsx` (route table — `/` and `/dashboard` not
  wrapped in `SubscriptionGate`)
- New test:
  `STUDENT/Frontend/src/features/subscription/pages/__tests__/SubscriptionPage.test.tsx`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** Same session as reported
