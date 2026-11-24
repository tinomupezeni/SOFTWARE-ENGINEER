# Replace the admin-login stopgap with a real session login/logout/CSRF flow

**Date:** 2026-11-24
**Project:** ZIMPHOS
**Type:** Feature (closes a previously-documented contract gap)
**Status:** Completed (PR #8 open, not yet merged/reviewed)

## Summary
The desk app had no login endpoint of its own — a known gap recorded in
`Project_Memory/ZIMPHOS/MAIN.md` ("still missing entirely: login/logout +
CSRF endpoints"). Users signing in were sent to Django's `/admin/login/`
page as a stopgap. Added `POST /api/login`, `POST /api/logout`, and
`GET /api/csrf` to the contract and backend, and rewired the frontend's
`SignedOut`/`SignOutButton` to use them.

## Context / Trigger
User asked why sign-in landed them on `http://localhost:5173/admin/login/?next=/`
while testing the app running locally via Docker. That turned out to be
expected behavior for the stopgap, not a bug — but the user then asked to
build the real flow, checking it against the existing OpenAPI contract.

## Scope
Included: login, logout, CSRF-cookie priming, the frontend form/button
wiring, rate limiting on login (added after a security review flagged its
absence against the project's own ECC security checklist), and production
cookie-security settings (also surfaced by that review). Excluded:
password reset, "remember me" / long-lived sessions, 2FA, and fixing the
unrelated known contract gaps already listed in `MAIN.md` (idempotent
counts, `/messages` scoping, etc.) — out of scope for this change.

## Method
Followed the project's contract-first workflow: `docs/contracts/openapi.yaml`
changed first (new `/csrf`, `/login`, `/logout` paths, `LoginRequest`
schema, `TooManyRequests` response), then `docs/contracts/api-types.ts`
and `docs/contracts/README.md` updated to match, then
`frontend/src/services/api/schema.d.ts` regenerated via `npm run gen:api`
(never hand-written) before any frontend code touched it. TDD: wrote
`backend/tests/test_auth_contract.py` first (confirmed RED — 404s —
before implementing the views), then implemented, then GREEN.

A security-reviewer pass was run against the implementation before
opening the PR (not after), covering: CSRF-bypass via disabled DRF auth
classes, timing/user-enumeration on login failure, rate limiting, session
fixation, and cookie-security settings.

## Decisions & Findings
- **Why `csrf_protect` is applied explicitly to `LoginView`:** DRF's
  `SessionAuthentication.enforce_csrf()` only runs once a session user has
  already been resolved — for an anonymous login POST it never fires, so
  the login endpoint would otherwise accept forged cross-site logins
  without a CSRF check. `@method_decorator(csrf_protect, name='dispatch')`
  closes that gap directly, verified by a test that asserts 403 with no
  CSRF token.
- **Why `GET /api/csrf` exists at all:** a browser with no session yet has
  no CSRF cookie to send back on the login POST. This primes it.
  `ensure_csrf_cookie` + `get_token()`, `AllowAny`, no auth classes.
- **Login error message is intentionally generic** ("Invalid username or
  password.") for both "no such user" and "wrong password" — verified this
  is also true at the Django `ModelBackend` level (it hashes the submitted
  password against a dummy user object when the username doesn't exist,
  specifically to keep timing similar between the two cases), so there's
  no secondary enumeration channel via timing either.
- **Rate limiting added after user sign-off**, not unilaterally: the
  security review flagged no throttling on `/login` as a HIGH finding
  against the project's own adopted `security.md` checklist ("rate
  limiting on all endpoints" is mandatory); since this was scope beyond
  what was explicitly asked, the user was asked first via a direct
  question before adding `apps.accounts.throttling.LoginRateThrottle`
  (5/min per client IP, DRF's `AnonRateThrottle`).
- **Cookie security settings are gated on `not DEBUG`, not hardcoded
  `True`:** `docker-compose.yml` runs `config.settings.production` locally
  with `DEBUG=True` over plain HTTP (not HTTPS). Hardcoding
  `SESSION_COOKIE_SECURE = True` would have silently broken local/demo
  login (browsers refuse to send a `Secure`-flagged cookie back over
  HTTP), so this is actual-prod-only (`DEBUG=False`) behavior.
- **`ALLOWED_HOSTS`'s existing `'*'` default was deliberately left
  unchanged**, despite the security review flagging it alongside the
  cookie settings — changing it risked locking out the currently-working
  local Docker deployment without separate coordination on what the real
  host allowlist should be. Left as a flagged-but-deferred item instead of
  bundled into this change.

## Changes Made
- `docs/contracts/openapi.yaml`, `docs/contracts/api-types.ts`,
  `docs/contracts/README.md`: new `/csrf`, `/login`, `/logout` paths,
  `LoginRequest` schema, `TooManyRequests` response.
- `backend/apps/accounts/{views,serializers,urls,throttling}.py`:
  `CsrfView`, `LoginView`, `LogoutView`, `LoginRequestSerializer`,
  `LoginRateThrottle`.
- `backend/config/settings/base.py`: `DEFAULT_THROTTLE_RATES`.
- `backend/config/settings/production.py`: `SESSION_COOKIE_SECURE`,
  `CSRF_COOKIE_SECURE`, `*_SAMESITE`, `CSRF_TRUSTED_ORIGINS` env hook.
- `backend/config/wsgi.py`: created (separate pre-existing bug, see
  `Backend_and_API/ZIMPHOS-2026-11-24-missing-wsgi-module.md`).
- `frontend/src/hooks/useAuth.ts` (new): `useLogin`, `useLogout`.
- `frontend/src/pages/SignedOut.tsx`: real username/password form.
- `frontend/src/components/SignOutButton.tsx`: posts to `/api/logout`.
- `frontend/src/services/api/client.ts`: added `apiPostEmpty` (a POST
  with no JSON body sends no `Content-Type`, otherwise the frontend's own
  contract-conformance test harness flags the empty body as "not JSON").
- `backend/tests/test_auth_contract.py` (new, 8 tests).
- `frontend/src/app/RoleGate.test.tsx`, `App.test.tsx`: updated for the
  real form/sign-out flow (previously asserted the `/admin/login/` link
  and a Django logout `<form>`).
- PR: https://github.com/winstonjthinker/Zimphos/pull/8 (open, not merged).

## Verification
- `pytest` (backend): 49/49 pass, including the 8 new auth tests.
- `vitest run` (frontend): 257/257 pass. `tsc -b`: clean.
- Verified end-to-end against the real backend running in Docker locally
  (not just mocked tests): `curl` through CSRF-prime → login → `/me` →
  logout → `/me` 401s again, both directly against the backend and
  through the Vite dev proxy.
- `manage.py check --deploy` run after the settings change: only
  DEBUG-related warnings remain locally (expected, since local Docker
  runs with `DEBUG=True`); no new warnings introduced by this change.

## Follow-ups / Deferred
- `ALLOWED_HOSTS = ['*']` in production settings — flagged by the
  security review, deliberately not changed here (see Decisions above).
  Needs a real host allowlist before an actual (non-Docker-local)
  deployment.
- The pre-existing contract gaps already listed in
  `Project_Memory/ZIMPHOS/MAIN.md` (count idempotency, `/messages`
  scoping, currency-change authorization, etc.) are untouched by this
  change.
- PR #8 has not been reviewed/merged as of this report.

## References
- `Project_Memory/ZIMPHOS/MAIN.md` (updated in the same session).
- `Backend_and_API/ZIMPHOS-2026-11-24-missing-wsgi-module.md` (the
  separate `wsgi.py` bug hit while running the stack locally, included in
  the same PR for convenience but logged separately since it's unrelated
  to the login flow itself).
- PR: https://github.com/winstonjthinker/Zimphos/pull/8
