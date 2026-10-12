# Retire the customer_profile localStorage cache; fetch profile from the backend

**Date:** 2026-10-12
**Project:** tese-marketplace (BFF architecture, store-api / customer-store)
**Type:** Architecture Decision / Refactor
**Status:** Completed

## Summary
Investigating "users can't update their profiles" traced to
`QuickSignupModal.tsx` missing `id`/`name` on login (its own bug entry),
but the deeper issue was architectural: `CustomerProfilePage` sourced
all of its data from a `customer_profile` localStorage key written
once, synchronously, at login time, with no backend fetch and no way to
self-heal if that write never happened - which it never did for the
app's most-used login path. Per explicit direction ("go further") this
went beyond patching the modal: retired the cache entirely in favor of
fetching the real profile from `GET /auth/me`, so profile data is
correct regardless of which of the app's several login entry points a
session came from.

## Context / Trigger
User: "check it out and tell me the issues" (investigation), followed
by "go further" after being offered a choice between patching
`QuickSignupModal.tsx` alone versus making `CustomerProfilePage` fetch/
derive from the backend session instead of depending on the fragile
cache at all.

## Scope
**Included:**
- `GET`/`PUT /auth/me` expanded to carry `phone`/`avatar_url`/
  `email_verified` (previously only `id`/`email`/`name`/`is_active`/
  `created_at`) - needed so the backend fetch actually has everything
  the profile UI displays.
- `useCustomerProfile`/`useProfileForm` rewritten to fetch and hold
  profile as async state (loading/error/refetch), not a synchronous
  cache read.
- `CustomerProfilePage` given a real loading spinner and a retry
  affordance on fetch failure, replacing a silent `return null` that
  looked identical whether the page was loading, broken, or logged out.
- `HeaderNavigation`'s avatar-initials fallback moved off the cache onto
  `useAuth().user.name` (removing its last reader).
- Dead cache writes removed from `LoginForm.tsx`/`AuthForm.tsx`.
- `QuickSignupModal.tsx`'s missing `id`/`name` bug (own entry) and its
  signup-branch not logging in after register, found and fixed in the
  same pass since it was directly entangled with this investigation.

**Explicitly excluded:**
- `QuickSignupModal.tsx`'s `toggleMode` not actually switching to signup
  mode (it navigates to `/signup` instead) - flagged, not changed, since
  it alters navigation/UX behavior that may be an intentional product
  decision (always collect signup info on the full page, not the quick
  modal) rather than a bug.
- `location` remains a UI-only field on the profile form - there's no
  backend column for it and adding one wasn't part of this fix.

## Method
Started from hard evidence, not assumption: checked `store-api`'s logs
first (a 10-day window had exactly one real `PUT /auth/me`, traced to
the investigator's own earlier test) to confirm the failure was
client-side before touching any code. Then traced the actual data flow
end to end (`handleSaveProfile` → `saveProfile` →
`customerProfileService.updateProfile` → `PUT /auth/me`) to find
precisely where it stopped, rather than guessing at the architecture.

Kept the existing `CustomerProfileData`/`ProfileFormState` shapes
unchanged specifically so downstream display components
(`ProfileHeader`, `AccountOverview`, `ProfileSettingsSection`) needed no
changes - only the *source* of that shape moved, from a cache read to a
backend fetch mapped through one shared function used for both `GET`
and `PUT` responses, so the UI is never relying on a locally-guessed
reconstruction of what the backend "probably" saved.

Verified with real headless-Chrome sessions driving the actual UI - not
curl against the backend alone, and not an injected/bypassed session -
specifically because an earlier bug this same day (the WebSocket
mixed-content issue) was only caught by testing through the real
frontend. That discipline caught a second, self-introduced regression
before it ever reached a user: `useProfileForm`'s `formState` only
initialized once on mount, so after switching `profile` to arrive
asynchronously, the Settings tab showed every field as "Not set" even
though the data had loaded correctly - fixed with an effect that syncs
`formState` from `profile` whenever it changes, skipping while the user
is actively editing.

## Decisions & Findings
- **The right fix was retiring the cache, not patching around it.**
  `QuickSignupModal.tsx`'s missing `id` explained the Save button's
  silent no-op, but even with that fixed, a user whose `customer_profile`
  cache was merely stale or had never been written for some other reason
  would still have hit the same blank-page failure mode. Fetching from
  the backend removes the entire class of bug, not just this instance
  of it.
- **Kept the exact same `CustomerProfileData` shape** rather than
  reworking every consumer component, by mapping the backend's
  `UserResponse` into it in one place (`mapUserResponseToProfile`) -
  minimized the blast radius of a change that's otherwise fairly deep
  (changing the fundamental timing model from synchronous to async).
- **`QuickSignupModal`'s unreachable signup branch was fixed but not
  made reachable** - fixing the dead code's correctness (so it's right
  if it ever does become reachable) was cheap and safe; changing
  `toggleMode` to actually enable in-modal signup is a product/UX
  decision affecting real navigation behavior, flagged for the user
  rather than decided unilaterally.
- **Testing through the real UI, not just the API, caught a real
  self-introduced regression** (the `formState` sync bug) before this
  report could claim the fix was verified - worth stating plainly since
  it's exactly the kind of bug that `curl`-only verification would have
  missed, the same lesson from the WebSocket fix earlier the same day.

## Changes Made
Backend (`apps/store-api`):
- `app/modules/auth/schemas/auth.py` - `UserResponse` gained `phone`,
  `avatar_url`, `email_verified`.

Frontend (`apps/customer-store`):
- `features/customer-profile/services/customerProfileService.ts` -
  `fetchProfile()` replaces `getLocalProfile()`; `updateProfile()`
  returns the backend's actual saved state via a shared mapper.
- `features/customer-profile/hooks/useCustomerProfile.ts` - `profile`
  is fetched async state (`isLoading`/`loadError`/`refetchProfile`);
  `useProfileForm` syncs `formState` from `profile` via effect instead
  of a one-time initializer.
- `features/customer-profile/pages/CustomerProfilePage.tsx` - loading
  spinner and retry UI replacing the old silent `return null`.
- `shared/navigation/HeaderNavigation.tsx` - avatar initials from
  `useAuth().user.name`.
- `shared/components/QuickSignupModal.tsx` - `id`/`name` on `login()`;
  auto-login after register.
- `features/auth/components/LoginForm.tsx`,
  `features/auth/pages/AuthForm.tsx` - removed dead `customer_profile`
  writes.

## Verification
- `python3 -m py_compile` / `npx tsc --noEmit` / production builds -
  clean at every step.
- Real headless-Chrome session: registered an account via the API,
  logged in through the actual `QuickSignupModal` (triggered via a
  product card's "Add" button as a guest, the real reachable path),
  confirmed the session correctly carried `id`/`name`, confirmed
  `/profile` loaded real data (not blank), navigated to Settings,
  clicked Edit, changed the phone number, saved, and confirmed via the
  `PUT /auth/me` response, the rendered UI, and a direct DB query that
  the new value persisted correctly.
- Caught and fixed the `formState` sync regression via this same
  end-to-end test before considering the work done.
- Final stack-wide smoke test (site, admin dashboard, clean
  `store-api` logs) after every deploy.

## Follow-ups / Deferred
- Decide whether `QuickSignupModal`'s "Sign up" link should actually
  enable in-modal signup (currently navigates to `/signup` instead,
  making the modal's signup branch unreachable in practice).
- `location` has no backend column - either add one or remove the field
  from the profile form if it's not meant to persist.

## References
- `Frontend_and_UI/tese-marketplace-2026-10-12-quicksignup-missing-session-id.md`
  (the specific bug found during this investigation)
- Key files: `apps/customer-store/src/features/customer-profile/hooks/useCustomerProfile.ts`,
  `apps/customer-store/src/features/customer-profile/services/customerProfileService.ts`,
  `apps/store-api/app/modules/auth/schemas/auth.py`

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~1.5 hours from report to verified fix in production, including a caught-and-fixed regression
