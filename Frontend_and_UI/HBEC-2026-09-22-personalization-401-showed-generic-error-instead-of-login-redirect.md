# A Parent Whose Session Died Mid-Wizard Got a Stuck Generic Error, Not a Login Redirect

**Date:** 2026-09-22
**Project:** HBEC
**Environment:** Staging (`hbca-vps`) — reproduced from real staging access logs, root-caused by reading `STUDENT/Frontend`'s own code
**Severity:** Medium (no data loss, no security exposure — a parent completing
a new child's personalization got stuck on a dead-end page instead of being
routed back to sign in)
**Status:** Resolved

## Summary
Reported as: a parent clicking through the "learning style" step of a new
child's personalization got `"Authentication credentials were not provided"`.
Staging access logs showed the real backend behavior was correct — the parent
had explicitly logged out, then failed two login attempts (wrong password),
then kept clicking around the app for ~3 minutes with no session at all,
during which every protected call — including the personalization save —
correctly 401'd. Once they logged in successfully, the exact same save
succeeded on the first try. No backend bug.

The real, fixable gap was on the frontend: this class of 401 (a real
authenticated action, rejected, unrecoverable) never told the app the session
was gone, and the one page it happened on has no route guard to redirect on
its own. The user's instinct was right: *"it shouldn't have displayed the
error, it should just have logged the user out to login page."*

## Symptoms
- Generic inline error on the child-personalization wizard's last step
  (`PersonalizationPage.tsx` in child mode), with no path back to signing in
  short of manually navigating to `/login`.
- Staging access log, same session:
  ```
  POST /api/auth/signup/parent/ 201 Created
  POST /api/auth/logout/ 200 OK
  POST /api/auth/login/ 401 Unauthorized   (x2, wrong password)
  GET  /api/parent/children/{id}/ 401 Unauthorized
  POST /api/parent/children/{id}/personalization/ 401 Unauthorized   (x3)
  POST /api/auth/login/ 200 OK
  POST /api/parent/children/{id}/personalization/ 200 OK   (first try, post-login)
  ```

## Investigation Steps

### 1. Initial Diagnosis
Ruled out the two obvious theories first, both cleanly:
- **Not a token-expiry race.** `ACCESS_TOKEN_LIFETIME` is 60 minutes,
  `REFRESH_TOKEN_LIFETIME` is 7 days; the entire incident spans under 5
  minutes.
- **Not a signup/login password mismatch.** `ParentSignupSerializer.create()`
  uses Django's standard `User.objects.create_user(password=...)`, which
  correctly hashes via `set_password()`. No divergence from how login checks it.

### 2. Root Cause Analysis
Read `STUDENT/Frontend/src/lib/api.ts` directly rather than inferring from
logs (an earlier pass in this same investigation incorrectly assumed the raw
DRF `"detail"` string reached the user — it doesn't; `apiFetch`'s error
parser only reads `errorData.message`, so an unmapped DRF exception falls
back to a generic `'API request failed'`).

The real gap: `apiFetch`'s 401 handler calls `refreshAccessToken()` and
retries only `if (newToken)`. When it's falsy — because there was no refresh
token (this session, post-logout) or because the refresh itself was
rejected — nothing happens. `notifyAuthLost()`, the one thing that flips the
app's `AuthContext` state to `'guest'` and tells the eventual login page a
session just ended, is called only from inside `_doRefresh()`'s own
*proactive* path (`ensureFreshToken()`), which deliberately stays quiet when
there's no refresh token at all — by design, so a page a genuine guest is
entitled to see doesn't get treated as a lapsed session. That's the right
call for a passive check. It's the wrong call for `apiFetch`'s *reactive*
path, where a real request was sent believing it was authenticated.

Compounding it: `/personalization` (`App.tsx`) is one of the only
authenticated-feeling routes **not** wrapped in `ProtectedRoute` — deliberate,
since the student's own post-signup flow can land here before the session is
fully hydrated — but that means child mode had no independent guard of its
own. Even with `notifyAuthLost()` firing, nothing on this specific route
would have reacted to the resulting `'guest'` state.

## Root Cause
Two gaps stacked: (1) `apiFetch`'s reactive 401-after-failed-refresh path
never announced the auth loss the way the proactive path does, and (2) the
one route that needed to react to that announcement isn't behind the app's
usual route guard, and had no fallback of its own.

## Prevention / Rule
**Guardrail:** `apiFetch`'s 401 handler now calls `notifyAuthLost()` whenever
the refresh attempt comes back empty — covered by a new test
(`api.test.ts`, `'fires when an authenticated action is rejected with no
refresh token to recover it'`) that pins this exact scenario: a real request,
not a passive check, failing with nothing left to retry. Any future caller of
`apiFetch` on an unguarded route inherits the fix automatically, rather than
needing its own ad hoc 401 handling.

## Solution

### Immediate Fix
1. `STUDENT/Frontend/src/lib/api.ts` — `apiFetch`'s 401 handler: added an
   `else { notifyAuthLost(); }` branch alongside the existing retry-on-success
   path. Scoped precisely to *reactive* failures (an actual request that
   failed and couldn't be recovered) — does not touch `ensureFreshToken()`'s
   deliberately-quiet passive-guest behavior, verified by the existing test
   `'stays quiet for someone who simply is not signed in'` still passing
   unchanged.
2. `STUDENT/Frontend/src/features/auth/pages/PersonalizationPage.tsx` —
   added a child-mode-scoped effect: when `status` resolves to anything
   other than `'authenticated'` (and isn't still `'loading'`), navigate to
   `/login`, carrying `from` the same way `ProtectedRoute` already does, so
   the parent lands back where they left off after signing back in.

### Verification
- New unit test added and passing (21/21 in `api.test.ts`, up from 20).
- Full frontend suite: 1254/1265 passing; the 11 failures are all in
  `TourManager.test.tsx` (`No QueryClient set` — a pre-existing test-harness
  gap last touched 2026-09-19, unrelated to this change, confirmed via `git
  log` before concluding so).
- `npm run typecheck`: clean.

## Prevention
- [x] Code changes required — done, both files
- [x] Documentation to update — this entry
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a

## Related Issues
None found for this exact gap. Distinct from
`HBEC-2026-09-15-harness-jwt-public-key-stale-after-partial-promotion-restart.md`
(same "401 not handled gracefully" shape, but that one was a harness/student
JWT public-key mismatch after a partial restart — a completely different root
cause, checked and ruled out early in this investigation).

## References
- `STUDENT/Frontend/src/lib/api.ts` (`apiFetch`, `_doRefresh`, `notifyAuthLost`)
- `STUDENT/Frontend/src/features/auth/pages/PersonalizationPage.tsx`
- `STUDENT/Frontend/src/features/auth/context/AuthContext.tsx` (`onAuthLost` listener)
- `STUDENT/Frontend/src/features/auth/components/ProtectedRoute.tsx`
- `STUDENT/Frontend/src/App.tsx` (`/personalization` route registration)
- `STUDENT/Frontend/src/lib/__tests__/api.test.ts`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — traced from a user report through
staging access logs, backend serializer/settings verification, and frontend
source, to a fix and passing tests.
