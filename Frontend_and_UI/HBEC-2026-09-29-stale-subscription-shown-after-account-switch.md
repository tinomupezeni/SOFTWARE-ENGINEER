# A New Signup Briefly Showed a Nonexistent 21-Day Trial — Stale React Query Cache Across Account Switches

**Date:** 2026-09-29
**Project:** HBEC
**Environment:** Production (live report, real account)
**Severity:** Medium
**Status:** Resolved

## Summary
User report, on a real account they created (`massala.care@gmail.com`)
on production: signup went through personalization straight into the
onboarding flow with no subscription/paywall step shown, and the
dashboard displayed "21 days left" despite no payment ever being made.
After refreshing the page, it correctly showed "Subscription Expired."
The user's own hypothesis was right: they had other test accounts
signed into the same browser session. Root cause: the student
frontend's `QueryClient` (`App.tsx`) is a single instance for the whole
app lifetime, and none of the six places `AuthContext.tsx` changes who
is signed in (`login`, `signup`, `parentSignup`, `googleSignIn`,
`logout`, `upgradeGuestToAccount`) ever cleared it — so a previous
account's cached subscription status (and any other per-user cached
query) stayed visible to whoever was signed in next, until that query's
own `staleTime` happened to expire or a hard reload forced a refetch.

## Symptoms
- A brand-new account shows an "active trial" with days remaining, with
  no subscription ever having been created for it.
- The discrepancy self-corrects on a hard page refresh.
- Only reproducible when multiple accounts have been used in the same
  browser session (tab or window) without a full reload between them.

## Environment Details
- **Server/Host:** production (`student.hbca.tech`)
- **Services Affected:** Student Frontend only
  (`STUDENT/Frontend/src/features/auth/context/AuthContext.tsx`,
  `App.tsx`'s `QueryClient`)
- **Time First Observed:** 2026-09-29, reported live by the user
  immediately after creating the account

## Investigation Steps

### 1. Initial Diagnosis
Before assuming a frontend bug, ruled out a real access-control failure
first, since that would be far more serious. Looked up the account
directly:
```sql
SELECT id, email, date_joined FROM accounts_user WHERE email = 'massala.care@gmail.com';
```
Then queried Payments (the subscription authority) directly for that
user id — `{"is_active": false, "status": "none", ...}`. No subscription
row exists for this account anywhere authoritative.

### 2. Root Cause Analysis
Checked student-backend's own logs for the exact signup timestamp
(`date_joined`) through several minutes after: every AI-gated request
(`/api/ai/analytics/spaced-repetition/`, `/report/`, `/velocity/`,
`/next-actions/`) returned `402 Payment Required`, repeatedly, from the
very first request onward. This ruled out a real backend/permission-gate
bypass — `HasActiveSubscription` had been correctly blocking this
account the entire time.

That left the display layer. Traced every place in the frontend that
renders the literal text "days left" — exactly one,
`STUDENT/Frontend/src/pages/Dashboard.tsx`, gated behind
`useSubscription()`'s `isActive`, which is computed from a live query
(`subscriptionKeys.status()`) via React Query. Checked where the
`QueryClient` powering that query is constructed:
`STUDENT/Frontend/src/App.tsx:80`, `const queryClient = new
QueryClient(...)` — module-scope, one instance for the entire app
session, never recreated. Checked every identity-changing function in
`AuthContext.tsx` (`login`, `signup`, `parentSignup`, `googleSignIn`,
`logout`, `upgradeGuestToAccount`) — none called
`queryClient.clear()`, `removeQueries()`, or `resetQueries()`; each just
overwrote local auth `state` directly.

### 3. Key Findings
- `logout()` did call `personalizationService.clear()`, so
  personalization-adjacent local state was already scoped correctly —
  the gap was specifically the React Query cache, a separate mechanism
  nobody had wired up the same way.
- The query key for subscription status (`['subscription', 'status']`)
  carries no user identifier — by design, since a single logged-in
  session only ever has one "current user" in mind — but that
  assumption breaks the moment two different accounts are used in the
  same browser session without a full reload.
- `login()` does not call `logout()` internally, so even switching
  accounts *without* an explicit logout click (submitting different
  credentials while still authenticated as someone else) hit the same
  gap — confirming all six transition points needed the fix, not just
  the obvious `logout()`.
- `staleTime: 5 * 60 * 1000` (5 minutes) on the subscription query is
  why a page reload eventually self-corrected on its own even before
  this fix — but 5 minutes of a new account seeing another account's
  subscription state (or worse, its dashboard analytics, if those
  queries have longer stale times) is a real, live-reported bug, not a
  hypothetical.

## Root Cause
`AuthContext.tsx`'s six identity-transition functions never cleared
React Query's single, app-lifetime `QueryClient`, so per-user cached
query results (subscription status confirmed; potentially other
per-user data cached the same way) leaked across an account switch
within one browser session until each query's own `staleTime` expired
or a hard reload forced a refetch.

## Prevention / Rule
**Guardrail:** any new function added to `AuthContext.tsx` that changes
`state.user` to a different identity (a new login method, a new signup
variant, an account-linking flow, etc.) must call `queryClient.clear()`
before or alongside that `setState` call. There are now six call sites
doing this consistently; a seventh identity-transition path that skips
it reintroduces the same class of bug for whatever data it caches.

## Solution

### Immediate Fix
`AuthContext.tsx`: added `const queryClient = useQueryClient();` inside
`AuthProvider` (valid because `AuthProvider` is rendered inside
`QueryClientProvider` in `App.tsx`), then called `queryClient.clear()`
at the success path of `login`, `signup`, `parentSignup`,
`googleSignIn`, `logout`, and `upgradeGuestToAccount` — every place the
authenticated identity changes.

Verified: `npm run typecheck` clean, production build succeeds. Shipped
to staging first, then promoted to production alongside a routine
retag-consistency step (all 10 canonical images retagged to the same
commit sha, though only student-frontend's content changed — matching
the previous day's established practice of keeping every service on one
consistent `TAG`). `verify-service-links.sh` and
`check_runtime_secret_drift.py` both clean post-deploy.

### Long-term Fix
None beyond the fix itself — the pattern (clear the query cache at
every identity transition) is now established and documented inline at
the point future additions would need to follow it.

## Prevention
- [x] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none; this is a display-only bug with
  no safe automated signal to alert on
- [x] Documentation to update — inline comment at the `useQueryClient()`
  call site in `AuthContext.tsx` explains the mechanism and the
  live report that surfaced it
- [x] Code changes required — done, staging and production verified

## Related Issues
- None directly, though this continues the same day-over-day pattern of
  finding real, live production bugs while investigating an initially
  different-sounding report (started as "payment is failing," turned
  into this cache-isolation bug once the specific account was traced).

## References
- `STUDENT/Frontend/src/features/auth/context/AuthContext.tsx`
- `STUDENT/Frontend/src/App.tsx` (`QueryClient` construction)
- `STUDENT/Frontend/src/pages/Dashboard.tsx` (where the stale value was
  actually rendered)
- `STUDENT/hbec_backend/apps/accounts/permissions.py`
  (`HasActiveSubscription` — confirmed correctly gating this account
  throughout, ruling out a real access bypass)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as report; staging and production
verified
