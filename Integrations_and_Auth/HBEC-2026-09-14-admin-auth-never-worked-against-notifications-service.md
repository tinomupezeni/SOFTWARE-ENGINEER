# Every real admin request to the NOTIFICATIONS service 401'd — admin and student sessions were never actually a shared verification scheme

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging (production intentionally untouched)
**Severity:** Critical (the entire admin-facing side of a shipped feature — notification drafts compose/approve/reject, and content-gap-report summaries — silently never worked for a real admin login)
**Status:** Resolved — verified live on staging

## Summary
The `NOTIFICATIONS` FastAPI service's `AdminUser` dependency (gating draft
compose/approve/reject and the content-gap-reports admin summary/count
endpoints) was built to verify admin sessions using the exact same RS256
JWT scheme used for student sessions. It never worked against a real
admin login: the admin backend signs its own tokens with a completely
different, symmetric (HS256) scheme, a different secret, and a different
user-id claim name. Every genuine admin request returned `401
Unauthorized`. This went undetected through the entire build of both the
original notifications drafts feature and the later content-gap-reports
feature because the automated test suite's `admin_token` fixture
constructed tokens using the same (wrong) scheme the code expected —
tests passed by testing the code against its own incorrect assumption,
not against reality.

## Symptoms
- A real admin, logged into staging, opened `/content-requests` and saw
  "No content requests yet" despite a student having already submitted a
  report minutes earlier (confirmed present in the database).
- `hbec-notifications-backend-staging`'s logs showed every single
  `GET /api/v1/content-gap-reports/summary` and `/outstanding-count`
  request from the admin frontend returning `401 Unauthorized` — dozens
  of them, one per poll interval, none ever succeeding.
- No error surfaced anywhere in the admin UI itself — `contentRequestsApi
  .ts` (and the equivalent for notification drafts) follow this repo's
  "never mock data" convention and return an empty result on any fetch
  failure, so a 401 looked visually identical to "genuinely zero
  requests."
- This almost certainly also affected the notification drafts
  compose/approve/reject feature built earlier the same day — it uses
  the exact same `AdminUser` dependency — though that wasn't separately
  reproduced with a live admin session in this investigation.

## Environment Details
- **Services Affected:** `hbec-notifications-backend-staging` (auth
  logic), `hbec-admin-backend-staging` (token issuance)
- **Related Components:** `NOTIFICATIONS/app/shared/auth.py`,
  `NOTIFICATIONS/app/shared/config.py`,
  `ADMIN/adminBackend/apps/accounts/serializers.py`
- **Time First Observed:** first real end-to-end use of the
  content-gap-reports admin dashboard by an actual logged-in admin,
  2026-09-14 (the feature itself had been "verified" earlier only via
  automated tests and unauthenticated-request 401 checks — never with a
  genuine admin session)

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the underlying data was correct first — queried
`content_gap_reports` directly on staging Postgres and re-ran the exact
aggregation SQL the summary endpoint uses by hand; both returned the
expected row. The bug was not in the data or the query logic.

### 2. Root Cause Analysis
Checked `hbec-notifications-backend-staging`'s logs for the actual
requests the admin's browser was making: every one came back `401`, not
`403` — a role-check failure would have been `403` (that path was never
even reached). That pointed at the JWT *verification* step itself
failing, not a role mismatch.

Read `ADMIN/adminBackend/config/settings/base.py`'s `SIMPLE_JWT` config
and `apps/accounts/serializers.py`'s `LoginSerializer.validate`:
- `ALGORITHM: "HS256"`, `SIGNING_KEY: _ADMIN_JWT_SIGNING_KEY` (which
  itself falls back to Django's own `SECRET_KEY` — `ADMIN_JWT_SECRET`
  was never actually set anywhere in any compose file).
- `USER_ID_CLAIM: "user_id"` — not `sub`.
- Tokens issued via a plain `RefreshToken.for_user(user)` call — no
  custom claims at all, meaning no `role` claim either.

Compared this against `NOTIFICATIONS/app/shared/auth.py`'s
`get_current_user()`/`require_admin_role()`: it only ever tried RS256
verification against the student backend's public key (or an HS256
fallback keyed on a *different* secret, `JWT_SECRET`, used only when no
RS256 key is configured at all — which it always is here). An
HS256-signed admin token, verified against an RS256 key it was never
signed with, fails at the decode step unconditionally — hence 401 on
every single request, with no path to ever succeed.

### 3. Key Findings
- Two backends, two completely independent auth systems: student
  sessions are RS256-asymmetric (student backend signs, everyone else
  only verifies with the public key); admin sessions are HS256-symmetric,
  signed and verified only within the admin backend itself, using a
  secret nothing else in the platform previously needed to know.
- The admin backend's issued tokens carried no `role` claim at all —
  even fixing the algorithm/secret mismatch wouldn't have been enough;
  `require_admin_role`'s `user.get("role") != "admin"` check would have
  permanently defaulted to a missing value and failed regardless.
- The test suite's own `admin_token` fixture
  (`NOTIFICATIONS/tests/conftest.py`) signed test tokens with the
  *student* scheme (`sub` claim, the student `JWT_SECRET`) and just set
  `role: "admin"` inside them — which is exactly what the (buggy) code
  expected, so every test passed. The tests proved the code was
  internally consistent, not that it matched the real admin backend.

## Root Cause
`NOTIFICATIONS`'s admin-auth dependency was designed as a variant of the
student-auth dependency (same function, different role check) rather
than as what it actually needed to be: a wholly separate verification
path for a wholly separate issuer, with its own secret, its own
algorithm, and its own claim names — and the admin backend never
embedded the one claim (`role`) that verification path would need to
check.

## Prevention / Rule
**Guardrail:** `scripts/check_config_parity.py`'s `CONTRACTS` registry
now includes an entry pairing `notifications`'s `ADMIN_JWT_SECRET` against
`admin-backend`'s `SECRET_KEY` — the same mechanism already used to catch
secret-wiring drift between other service pairs (harness↔student,
payments↔student, admin-backend↔schools-backend). This specific class of
bug (two sides of an auth relationship built by different work streams,
each testing itself against its own assumption) is harder to catch
generically; the closest durable guardrail is: **any new
cross-service-auth dependency must be built by first reading the actual
issuer's token-generation code** (not assumed to match an existing
pattern from a different issuer), and its test fixtures must construct
tokens by mirroring that real issuer's exact signing scheme, never a
copy-pasted fixture from a different auth domain.

## Solution

### Immediate Fix
- **`ADMIN/adminBackend/apps/accounts/serializers.py`** —
  `LoginSerializer.validate` now sets `refresh["role"] = user.role`
  before deriving the access token, so every issued token (and every
  token derived from a refresh, since `RefreshToken.access_token` copies
  non-reserved claims from the refresh token's own payload) carries the
  admin's real role (`super_admin`/`admin`/`editor`/`viewer`).
- **`NOTIFICATIONS/app/shared/auth.py`** — added
  `get_current_admin_user()`, a genuinely separate verification path:
  HS256 + `ADMIN_JWT_SECRET`, reads `user_id` (not `sub`), defaults
  `role` to an empty string (no sensible "least privilege that still
  makes sense" default the way student's `role` can safely default to
  `"student"`). `require_admin_role` now depends on this instead of the
  student `get_current_user`, and checks membership in
  `{"super_admin", "admin", "editor"}` (matching the admin backend's own
  `AdminUser.is_editor_role` convention) rather than a single hardcoded
  `"admin"` string.
- **`NOTIFICATIONS/app/shared/config.py`** — new `ADMIN_JWT_SECRET`
  setting, included in production secret validation.
- **`docker-compose.yml`/`.staging.yml`/`.production.yml`** — all three
  notifications service blocks (web, worker, beat) now get
  `ADMIN_JWT_SECRET: ${ADMIN_SECRET_KEY:?...}` — reusing the admin
  backend's existing signing secret rather than provisioning a new one.
- Test fixtures (`NOTIFICATIONS/tests/conftest.py`) got a new
  `make_admin_token()` helper matching the real admin scheme exactly
  (different secret from the student one, `user_id` claim, `role` set
  explicitly), plus `editor_token`/`viewer_token` fixtures. Every
  existing test that had asserted a student-scheme token got `403`'d on
  an admin route was corrected to `401` (the real, more correct
  behavior — a student-scheme token can't authenticate on an admin route
  at all now, it doesn't get far enough to be role-checked), and new
  tests assert the reverse-direction proof: a student-scheme token with
  `role: "admin"` baked into it still fails on an admin route, an
  admin-scheme token with the wrong secret fails, a `viewer`-role admin
  is correctly `403`'d, and an `editor`-role admin is correctly allowed.
- Added a matching test on the admin-backend side
  (`ADMIN/adminBackend/apps/accounts/tests/test_login.py`) asserting the
  issued access token, refresh token, and a refreshed access token all
  carry the user's real `role` claim.

Verified live on staging: rebuilt and force-recreated
`notifications`/`notifications-worker`/`notifications-beat` and
`admin-backend`/`admin-worker`/`admin-beat`; a real admin session's
`GET /content-gap-reports/summary` now returns the actual data instead
of a silent `401`.

### Long-term Fix
None needed beyond the guardrail above and the now-corrected test
fixtures — the fix is complete and correctly scoped.

## Prevention
- [ ] Configuration changes needed — n/a (fixed directly; no new secret
      provisioned, reused `ADMIN_SECRET_KEY`)
- [ ] Monitoring/alerts to add — worth alerting on a sustained run of
      401s against any single AdminUser-gated route, since (as here) it
      can silently render an entire admin feature non-functional with no
      visible error.
- [ ] Documentation to update — n/a
- [x] Code changes required — done, both sides (admin backend token
      issuance, notifications service token verification)

## Related Issues
- Same day, same feature build: `HBEC-2026-09-14-content-gap-reports-unrouted-in-nginx.md`
  — a different gap in the same content-gap-reports rollout, also only
  found via genuine end-to-end verification rather than automated tests
  or synthetic-token checks.

## References
- `NOTIFICATIONS/app/shared/auth.py`
- `NOTIFICATIONS/app/shared/config.py`
- `NOTIFICATIONS/tests/conftest.py`
- `ADMIN/adminBackend/apps/accounts/serializers.py`
- `ADMIN/adminBackend/apps/accounts/tests/test_login.py`
- `ADMIN/adminBackend/config/settings/base.py` (`SIMPLE_JWT`)
- `scripts/service_contracts.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery — root-caused, fixed on
both sides, tested, and verified live on staging within the same
investigation.
