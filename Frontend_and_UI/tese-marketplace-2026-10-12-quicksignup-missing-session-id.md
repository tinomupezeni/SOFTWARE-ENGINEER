# Users couldn't update their profile - the most-used login modal never set the session's user id

**Date:** 2026-10-12
**Project:** tese-marketplace (BFF architecture, customer-store)
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
`QuickSignupModal.tsx` - wired into 14 different files across nearly
every page (product cards, header nav, mobile menu, every marketplace
page) and very likely the dominant login entry point - called `login()`
without including `id` or `name` on the session object. Any session that
originated there had `useAuth().user.id === undefined`, and
`CustomerProfilePage`'s Save button explicitly guards on it
(`if (profile?.user?.id) saveProfile(...)`), so the click silently did
nothing: no network request, no error, no toast.

## Symptoms
- User report: "users can't update their profiles."
- `docker logs tese-store-api --since 240h | grep 'auth/me'` showed
  exactly one `PUT /api/auth/me` in 10 days, and it was traced to the
  investigating session's own earlier test - meaning real users' save
  attempts were never reaching the backend at all.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-store-api` +
  `tese-customer-store` containers)
- **Services Affected:** Profile editing for any session originating
  from the Quick Signup modal (likely the majority of sessions, given
  how widely it's used compared to the dedicated `/login` page)
- **Related Components:**
  `apps/customer-store/src/shared/components/QuickSignupModal.tsx`,
  `apps/customer-store/src/features/customer-profile/pages/CustomerProfilePage.tsx`
- **Time First Observed:** 2026-10-12

## Investigation Steps

### 1. Initial Diagnosis
Checked `store-api` logs for any 4xx/5xx or profile-related activity
over a wide window before touching any code - found real traffic
elsewhere (bot scanning noise, legitimate 401/422s on other endpoints)
but zero genuine `PUT /auth/me` attempts, ruling out a server-side bug
and pointing at a client-side request that never fires.

### 2. Root Cause Analysis
Traced the real save path: `CustomerProfilePage.tsx`'s
`handleSaveProfile` → `useProfileForm`'s `saveProfile` →
`customerProfileService.updateProfile` → `PUT /auth/me`. All correct
code, but gated on `profile?.user?.id`, sourced from a `customer_profile`
localStorage cache written only at login time. Grepped every file that
writes that cache (`LoginForm.tsx`, `AuthForm.tsx`,
`QuickSignupModal.tsx`) and found `QuickSignupModal.tsx`'s login branch
never wrote it at all, and its `login({...})` call omitted `id` (and
`name`) entirely - compared directly against `LoginForm.tsx`'s version,
which correctly includes `id: response.user?.id || ""`.

### 3. Key Findings
- `CustomerProfilePage.tsx` had `if (!profile) return null;` with a
  comment claiming "useCustomerProfile will redirect" - false: that
  redirect only fires when unauthenticated. An authenticated user with
  no `customer_profile` cache entry (i.e., any Quick Signup Modal login)
  saw a permanently blank `/profile` page, not just a broken save
  button.
- The modal's signup branch (the `else` of `isLoginMode`) is actually
  unreachable in practice: its "Sign up" link calls `navigate('/signup')`
  rather than ever flipping `isLoginMode` to `false` - the modal only
  ever operates in login mode. Fixed its auto-login-after-register logic
  anyway (harmless, correct-in-spirit), but flagged rather than silently
  changed the navigation behavior that makes it unreachable, since that
  may be an intentional product decision, not a bug.
- Checked gravity/reach before fixing: `grep -rln` across
  `apps/customer-store/src` for `QuickSignupModal` returned 14 files -
  this is not an edge-case entry point.

## Root Cause
`QuickSignupModal.tsx`'s `login({...})` call was written independently
of `LoginForm.tsx`'s (duplicated logic, not shared), and the duplicate
omitted fields the original correctly included - a copy-paste drift
between two implementations of "log the user in" that should never have
diverged.

## Prevention / Rule
**Guardrail:** Every call site that constructs the session object passed
to `useAuth().login()` must include every field the type declares,
checked by grep (`grep -rn "login({" src`) whenever a new login entry
point is added - this exact drift (one caller matching the type, another
silently omitting fields) is invisible to TypeScript when the object
literal still satisfies a loosely-typed or partial interface.

## Solution

### Immediate Fix
`apps/customer-store/src/shared/components/QuickSignupModal.tsx`:
- Login branch: added `id: responseData.user?.id || ""` and
  `name: responseData.user?.name || ""` to the `login({...})` call.
- Signup branch: now logs in immediately after a successful
  `authService.register()` call (which doesn't return a session), with
  the same corrected `login({...})` shape - previously this branch
  called `register()` and nothing else, leaving the user logged out
  after the modal's `window.location.reload()`.

See the companion report for the deeper fix (retiring the
`customer_profile` cache this bug was interacting with) and its own
verification.

```bash
npx tsc --noEmit                     # clean
pnpm --filter customer-store build   # clean production build
```
Verified with a real headless-Chrome session driving the actual modal
(not a bypassed/injected session): registered a test account via the
API, triggered the modal from a product card's "Add" button as a guest,
logged in through it, and confirmed `localStorage["tese_auth_user"]`
correctly contained both `id` and `name` afterward.

### Long-term Fix
Covered by the companion report - `/profile` no longer depends on a
cache this modal would otherwise still need to remember to write.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `reports/tese-marketplace-2026-10-12-profile-fetch-from-backend.md`
  (the deeper fix this bug was found and resolved under)

## References
- `apps/customer-store/src/shared/components/QuickSignupModal.tsx`
- `apps/customer-store/src/features/customer-profile/pages/CustomerProfilePage.tsx`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~40 minutes from report to verified fix in production
