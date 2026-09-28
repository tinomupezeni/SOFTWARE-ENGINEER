# Session silently lost on any page reload - authStorage was memory-only

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, customer-store)
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
`apps/customer-store/src/core/utils/authStorage.ts` held the logged-in
user (and the token `axiosInstance` reads for the `Authorization` header)
in a plain in-memory JS module variable, with no persistence to
`localStorage`/`sessionStorage`/cookies at all. Any full page reload -
refreshing the tab, reopening a bookmarked page, opening a new tab -
silently wiped the session, even though the refresh token was still
valid, and the user was bounced to `/login` with no explanation.

## Symptoms
- User report: "we seem to not have the add products for any of the 3
  users https://tesemarket.com/profile, users no longer [able] to submit
  partnership request."
- Reproduced with a real end-to-end Playwright run against production:
  login -> `/profile` -> Partner tab -> Start Application -> submit
  worked perfectly *within one continuous browser session*. A hard
  reload on `/profile` immediately redirected to `/login` and the
  Partner tab (and the entire profile UI) disappeared.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-customer-store`
  container)
- **Services Affected:** All of `customer-store` - anything gated behind
  `useAuth()`/`isAuthenticated` (profile, cart checkout requiring login,
  messaging, self-listing) would silently log a user out on reload
- **Related Components:**
  `apps/customer-store/src/core/utils/authStorage.ts`,
  `apps/customer-store/src/core/providers/AuthContext.tsx`,
  `apps/customer-store/src/core/context/axiosInstance.ts`
- **Time First Observed:** 2026-09-28, user report shortly after an
  unrelated redesign deploy

## Investigation Steps

### 1. Initial Diagnosis
The report named a specific symptom (can't submit a partner application),
so tested the backend endpoint directly first rather than assuming the
frontend:
```bash
curl -X POST https://tesemarket.com/api/auth/applications \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"application_type":"farmer","business_name":"Debug Farm Co", ...}'
# -> 200, application created cleanly
```
Backend was fine, which pointed at the frontend.

### 2. Root Cause Analysis
Installed Playwright's browser via the system Chrome (`channel: 'chrome'`,
since the sandboxed Linux environment's OS wasn't in Playwright's
supported-browsers list) and drove the real UI end to end against
production:
```bash
node .debug_partner2.mjs   # full login -> profile -> partner -> submit flow
# -> worked perfectly in one session
node .debug_partner3.mjs   # same flow, then page.reload() on /profile
# -> immediately redirected to /login, Partner tab gone
```
Then read `authStorage.ts`: `let memoryUser: User | null = null;` with no
read/write to any browser storage anywhere in the module - confirmed via
`git log` that this file hadn't been touched by any commit this session
(last touched in the June "Modular Monolith" consolidation), ruling out
today's deploy as the cause.

### 3. Key Findings
- `AuthContext.tsx`'s mount-time hydration already correctly calls
  `authStorage.getUser()` synchronously on load - the bug was entirely
  in `authStorage` never having anything to return after a reload, not
  in how it's consumed.
- A separate, unrelated localStorage-based token mechanism exists in
  `features/auth/services/authService.ts` (`storeTokens`/`getStoredToken`
  using `access_token`/`refresh_token` keys) but nothing in the real login
  path calls it - it's dead/parallel code, not what's actually used.

## Root Cause
`authStorage` was written as an in-memory cache "to avoid race conditions
in Axios interceptors during React hydration" (per its own comment) but
never actually got a persistence layer added underneath that cache - so
every reload started from a clean, empty module scope.

## Prevention / Rule
**Guardrail:** Any module that is the single source of truth for auth
state must have an automated test asserting a session survives a
simulated page reload (e.g., a Playwright test that logs in, calls
`page.reload()`, and asserts the user is still authenticated) as part of
the auth test suite - this is exactly the kind of defect that's invisible
in a single unbroken dev session (`npm run dev` with hot reload never
truly reloads the JS module scope the way a production page load does)
and only surfaces once real users close tabs and come back.

## Solution

### Immediate Fix
`authStorage.ts` now persists the user object to `localStorage` (key
`tese_auth_user`) on every `setUser`/`setTokens`/`clear`, and initializes
the in-memory cache by reading it back at module load - keeping the same
synchronous API (`getUser()`, `getToken()`, etc.) so no caller, including
`AuthContext.tsx`, needed to change. Wrapped reads/writes in try/catch
for private-browsing/storage-disabled environments, falling back to
in-memory-only rather than throwing.

Verified against production with the same Playwright reproduction: login
-> reload `/profile` -> session and Partner tab both survive -> partner
application submits successfully.

### Long-term Fix
Add a reload-survives-session Playwright test to the auth test suite (see
Prevention/Rule). Consider also cleaning up the dead, parallel
`storeTokens`/`getStoredToken` localStorage mechanism in `authService.ts`
so there's only one source of truth for tokens.

## Prevention
- [x] Code changes required (done this session)
- [ ] Add reload-persistence Playwright test to the auth suite
- [ ] Remove or consolidate the unused parallel token-storage mechanism
      in `authService.ts`

## Related Issues
- Reported alongside a Google OAuth 404 in the same message; see
  `Integrations_and_Auth/tese-marketplace-2026-09-28-google-oauth-endpoint-never-implemented.md`
  for that separate, also-real issue from the same conversation.

## References
- `apps/customer-store/src/core/utils/authStorage.ts`
- `apps/customer-store/src/core/providers/AuthContext.tsx`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~35 minutes from report to verified fix in production
