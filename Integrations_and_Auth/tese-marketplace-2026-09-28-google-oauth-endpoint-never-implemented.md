# Google sign-in 404s in production - backend endpoint was never implemented

**Date:** 2026-09-28
**Project:** tese-marketplace (BFF architecture, store-api / customer-store)
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
`POST /api/auth/google` returned 404 in production. The frontend has always
had a complete Google OAuth flow (`SocialLoginButtons.tsx`, a real
`VITE_GOOGLE_CLIENT_ID`, `authService.googleLogin()`) and the `User` model
already has a `google_id` column, but the corresponding backend route,
schema, and verification logic were never written.

## Symptoms
- User reported "failing to login" right after a deploy, with a browser
  console log showing `POST https://tesemarket.com/api/auth/google 404
  (Not Found)` and `ApiError: An unexpected error occurred.` after the
  Google OAuth popup completed.
- Regular email/password login errors ("Invalid credentials") were pasted
  in the same report, initially raising suspicion of a broader login
  regression from the deploy.

## Environment Details
- **Server/Host:** Production VPS (159.198.42.231), `tese-store-api`
  container
- **Services Affected:** `store-api` auth module; `customer-store` login
  and signup pages
- **Related Components:** `apps/store-api/app/modules/auth/routes/auth.py`,
  `services/auth_service.py`, `schemas/auth.py`;
  `apps/customer-store/src/features/auth/services/authService.ts`,
  `components/SocialLoginButtons.tsx`
- **Time First Observed:** 2026-09-28, minutes after deploying the Apple
  HIG customer-store redesign

## Investigation Steps

### 1. Initial Diagnosis
Two errors were reported together. Triaged them as separate issues rather
than assuming both were caused by the deploy.

### 2. Root Cause Analysis
```bash
# Regular login - test against the known seeded admin account directly
curl -X POST https://tesemarket.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@tesemarket.com","password":"Admin@123"}'
# -> 200 with a valid token, proving login itself was not broken

# Google login - check for a backend route
grep -rn "google" apps/store-api/app/modules/auth/routes/auth.py
# -> no matches; grep for existing scaffolding
grep -n "google_id" apps/store-api/app/modules/auth/models/user.py
# -> column exists, but no schema/route/service ever built around it
```
`seed.py` resets the seeded admin's password to a known value
(`Admin@123`) on every application startup, which made it possible to get
a clean, unambiguous answer on whether login itself worked, independent of
whatever credentials the reporting user had actually tried.

### 3. Key Findings
- Regular login was never broken; the "Invalid credentials" report was the
  user's own test credentials not matching an existing account.
- The Google OAuth gap was genuinely pre-existing - not introduced by the
  deploy - but a fix earlier in the same session to the frontend's dead
  "Sign up with Google" handler (previously a no-op `console.log`) made
  the gap visible for the first time: the frontend now actually calls the
  endpoint instead of silently swallowing the click.
- No Google client secret or verification library was configured on the
  backend at all (`grep -i google apps/store-api/requirements.txt` and
  `config.py` both empty), confirming this was never wired up, not just
  broken.

## Root Cause
The frontend's Google sign-in UI was built assuming a backend endpoint
that a backend engineer never implemented - a cross-team/cross-PR
integration gap. It stayed invisible because the frontend's own handler
for the flow was, until this session, itself a no-op stub that never
actually called the endpoint.

## Prevention / Rule
**Guardrail:** Any frontend auth provider button (OAuth, SSO, etc.) must
have its corresponding backend route covered by an integration test that
hits the real route path before that UI ships - a test asserting
`POST /api/auth/google` returns something other than 404 would have
caught this at PR time instead of in production. More generally, a
smoke test suite (this repo already has one in `smoketest/`) should
include one request per auth provider surfaced in the UI, not just the
primary email/password path.

## Solution

### Immediate Fix
Implemented `POST /api/auth/google` in `store-api`:
- `schemas/auth.py`: added `GoogleLoginRequest { token: str }`.
- `services/auth_service.py`: added `authenticate_google_user()`, which
  verifies the access token against Google's userinfo endpoint
  (`https://www.googleapis.com/oauth2/v3/userinfo`) via `httpx` (already
  a dependency, no new library needed - the frontend uses the implicit
  flow, which yields an access token, not a verifiable ID token JWT),
  then finds-or-creates the user: matches by `google_id` first, falls
  back to linking an existing email account, otherwise creates a new
  user with no password.
- `routes/auth.py`: added the route, reusing the existing
  `create_user_tokens()` to issue the same JWT pair `/login` returns.

### Long-term Fix
Add the auth-provider integration test described above to
`smoketest/customer_auth_smoke.py` so a future frontend-only fix to a
dead OAuth handler can't silently ship without the backend counterpart
being verified to exist.

## Prevention
- [x] Code changes required (done this session)
- [ ] Add Google OAuth path to `smoketest/customer_auth_smoke.py`
- [ ] Documentation to update: note in the auth module that Google login
      uses the implicit/access-token flow, not ID-token verification

## Related Issues
- Found immediately after
  `reports/tese-marketplace-2026-09-28-farmer-self-listing.md`'s sibling
  redesign session; the frontend half of this bug (dead Google sign-up
  handler) was fixed as part of that session's auth-pages redesign
  commit, which is what made this backend gap visible.

## References
- `apps/store-api/app/modules/auth/routes/auth.py`
- `apps/store-api/app/modules/auth/services/auth_service.py`
- `apps/customer-store/src/features/auth/components/SocialLoginButtons.tsx`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~25 minutes from report to verified fix in production
