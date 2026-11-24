# Real session login/logout/CSRF flow (PR #8)

**Date:** 2026-11-24

## What happened
Added `POST /api/login`, `POST /api/logout`, `GET /api/csrf` to the
contract and backend, closing the "still missing entirely: login/logout +
CSRF endpoints" gap. Rewired `SignedOut.tsx`/`SignOutButton.tsx` to use
them instead of Django's `/admin/login/`/`/admin/logout/`. Full write-up:
`reports/ZIMPHOS-2026-11-24-real-login-csrf-flow.md`.

## Why this is worth a change-history entry
Two things aren't obvious from the diff:
- `LoginView` has `authentication_classes = []` (disabling DRF's own auth
  layer) but still needs CSRF protection, because DRF's
  `SessionAuthentication.enforce_csrf()` only runs once a session user is
  already resolved — never for an anonymous POST. It gets CSRF protection
  back via `@method_decorator(csrf_protect, name='dispatch')` applied
  directly to the view, independent of DRF's auth stack entirely.
- `production.py`'s new `SESSION_COOKIE_SECURE`/`CSRF_COOKIE_SECURE` are
  gated on `not DEBUG`, not hardcoded `True` — `docker-compose.yml` runs
  this exact settings module locally over plain HTTP with `DEBUG=True`;
  hardcoding `Secure=True` would have silently broken local/demo login
  (browsers won't send a `Secure` cookie back over HTTP).

## Verification
- `pytest` (backend, 49 tests) and `vitest run` (frontend, 257 tests) pass.
- Verified against the real backend in Docker with `curl`: CSRF-prime →
  login → `/me` → logout → `/me` 401s again.

## Follow-ups
- PR #8 not yet merged/reviewed.
- `ALLOWED_HOSTS = ['*']` in production settings was flagged by a security
  review as a related gap but deliberately left unchanged in this PR —
  needs a real host allowlist before an actual deployment.
