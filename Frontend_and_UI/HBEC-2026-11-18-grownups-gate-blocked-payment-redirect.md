# GrownUpsGate wrapped the payment-gateway redirect-back route it was told not to

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in code review of PR #149, `experimental` branch, before merge to `master`)
**Severity:** Medium
**Status:** Resolved

## Summary
PR #149 added `GrownUpsGate` (a sessionStorage-based parental math-gate for
ECD-Grade 5 accounts, Kids board rule 7) around the subscription/payment/
settings routes. It included `/payment/status/:paymentId` in that wrap —
but that exact route already carried a comment stating it is the external
payment gateway's redirect-back target and "must stay reachable
unconditionally," because it was previously carved out of `SubscriptionGate`
for the same reason (to avoid a redirect loop). The new gate reintroduced the
problem the existing comment was written to prevent, for a junior-banded
account or a parent using the child's session.

## Symptoms
A junior-banded account (or a parent using a child's session) returning from
an external payment gateway to `/payment/status/:paymentId` would see the
grown-ups math gate instead of the payment result, in any context where
tab-scoped sessionStorage isn't available (a new tab/webview opened by a
mobile payment SDK) or the 10-minute unlock window has lapsed.

## Environment Details
- **Server/Host:** Student Frontend (`STUDENT/Frontend`)
- **Services Affected:** `src/App.tsx` route table; `GrownUpsGate` component.
- **Related Components:** `SubscriptionGate` (the earlier gate this same
  route was already carved out of, for the identical reason).
- **Time First Observed:** Found during code review, not yet reported live.

## Investigation Steps

### 1. Initial Diagnosis
Code review of PR #149 noticed the route's own adjacent comment block
("these must stay reachable for a user with no active subscription/trial...")
already documents the constraint this route must satisfy, and that
`GrownUpsGate` was added in direct contradiction to it a few lines below.

### 2. Root Cause Analysis
The Kids-board rule-7 change ("Payments and settings sit behind the
grown-ups gate for ECD to Grade 5") was applied uniformly to every route
under the `/subscription`, `/payment`, `/profile` heading without checking
whether each route carried its own pre-existing reachability constraint.
`/payment/status/:paymentId` did.

### 3. Key Findings
- The failure mode is tab/session-scoped and time-windowed (10-minute
  unlock), so it would not reproduce on every payment, making it the kind of
  intermittent bug that is hard to diagnose from a support report alone.

## Root Cause
A blanket rule ("gate payments/settings for junior accounts") was applied to
a route list without checking each route against its own pre-existing,
explicitly documented reachability requirement.

## Prevention / Rule
**Guardrail:** Before wrapping a route in a new access gate, grep for
existing comments on that route (and on sibling routes doing the same job,
e.g. `SubscriptionGate`'s carve-out of this exact path) that document a
reachability requirement, and treat any such comment as a blocking
constraint on the change, not just documentation to read past.

This closes the gap because the root cause was a rule applied without
reconciling it against a constraint already written down one git-blame
hop away.

## Solution

### Immediate Fix
Removed `GrownUpsGate` from `/payment/status/:paymentId` only (left it on
`/subscription`, `/subscription/pay`, and `/profile`), and added a comment
restating the constraint at that route so a future similar change has the
same warning in the same place.

### Long-term Fix
None beyond the fix above; this is a single-route carve-out, not a pattern
needing a structural change.

## Prevention
- [x] Code changes required (done — see Solution)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Found alongside two other PR #149 review findings: a picture-swap
  deduplication bug and an empty-options bounds-check gap, both in the
  backend/harness.

## References
- `STUDENT/Frontend/src/App.tsx`
- HBEC `experimental` branch, commit `5532043e3`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session (pre-merge)
