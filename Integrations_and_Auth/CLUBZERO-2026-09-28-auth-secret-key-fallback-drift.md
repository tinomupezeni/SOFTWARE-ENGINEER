# `auth.py` verified JWTs against a different fallback `SECRET_KEY` than `security.py` used to sign them

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** High (would have silently broken `/auth/refresh` for every real deployment that doesn't set `SECRET_KEY` explicitly)
**Status:** Resolved

## Summary
While fixing the broken refresh-token flow
([[CLUBZERO-2026-09-28-refresh-token-endpoint-cannot-ever-succeed]]),
implemented real refresh tokens and re-tested end to end — and
`/auth/refresh` still 401'd on a genuinely valid refresh token. The
cause: `club-zero-backend/app/routers/auth.py` declared its own
module-level `SECRET_KEY = os.getenv("SECRET_KEY", "your-fallback-secret-key")`,
while `club-zero-backend/app/security.py` — the only place any token is
actually signed, via `create_access_token`/`create_refresh_token` — uses
`SECRET_KEY = os.getenv("SECRET_KEY", "supersecret-dev-key")`. Both read
the same environment variable, so this is invisible whenever
`SECRET_KEY` is set explicitly (e.g. in production), but with no env var
set at all — the default state of a fresh dev checkout, and of this
project's own `docker-compose.yml` unless `SECRET_KEY` is exported first
— every token gets signed with `"supersecret-dev-key"` and
`/auth/refresh` verifies it against `"your-fallback-secret-key"`,
so decoding always fails signature verification and returns 401.

## Symptoms
- A manual end-to-end check (register → login → `POST /auth/refresh`
  with the real, unexpired `refresh_token` just issued by `login`)
  returned `401 {"detail": "Token expired or invalid"}` instead of a new
  token pair, even immediately after issuance.
- This is exactly the kind of failure that looks identical to "the
  refresh token really did expire" from the client's point of view,
  making it likely to be misdiagnosed as a token-lifetime bug rather
  than a signing-key mismatch.

## Environment Details
- **Server/Host:** Local dev (FastAPI backend, no `SECRET_KEY` env var
  set — the default local/dev condition)
- **Services Affected:** `club-zero-backend/app/routers/auth.py`,
  `club-zero-backend/app/security.py`
- **Time First Observed:** 2026-09-28, while manually verifying the
  refresh-token fix.

## Investigation Steps

### 1. Initial Diagnosis
Re-ran the login → refresh manual check after implementing
`create_refresh_token()` and wiring `/auth/refresh` to mint a new token
pair; still got 401 on a token that should have been valid.

### 2. Root Cause Analysis
```python
# app/security.py:6 — used to SIGN every token
SECRET_KEY = os.getenv("SECRET_KEY", "supersecret-dev-key")

# app/routers/auth.py:14 (before fix) — used to VERIFY in /auth/refresh
SECRET_KEY = os.getenv("SECRET_KEY", "your-fallback-secret-key")
```
Two independent `os.getenv("SECRET_KEY", <different default>)` calls
for what must be the same value. With the env var unset, they resolve
to two different strings, so any token signed via `security.py` fails
`jose.jwt.decode()`'s signature check in `auth.py`.

### 3. Key Findings
- `get_current_user` (`dependencies.py`) and `websockets.py` both
  correctly import `SECRET_KEY`/`ALGORITHM` from `security.py`, so
  regular access-token verification (login-gated REST calls, WebSocket
  auth) was never affected — only `auth.py`'s locally-redeclared copy
  was wrong, which happened to be exactly the endpoint
  ([[CLUBZERO-2026-09-28-refresh-token-endpoint-cannot-ever-succeed]])
  being fixed in the same session.

## Root Cause
`SECRET_KEY` (and its fallback default) was declared independently in
two files instead of defined once and imported, and the two fallback
strings drifted apart at some point without anyone noticing — nothing
exercised `/auth/refresh` against a real, unset-env-var dev environment
until this session.

## Prevention / Rule
**Guardrail:** There must be exactly one definition of `SECRET_KEY` /
`ALGORITHM` in the codebase (`security.py`); every other module that
needs them imports from there, the way `dependencies.py` and
`websockets.py` already did. A grep for `os.getenv("SECRET_KEY"` should
only ever return one hit.

## Solution

### Immediate Fix
Removed `auth.py`'s local `SECRET_KEY`/`ALGORITHM` declarations and
`import os`; now imports both from `app.security` alongside the token
factories it already imported from there. Re-verified: login → refresh
now returns `200` with a fresh access/refresh pair.

### Long-term Fix
Done — see Immediate Fix. No further duplication of this constant
remains in the codebase.

## Prevention
- [x] Remove the duplicate `SECRET_KEY` declaration in `auth.py`
- [x] Re-verify `/auth/refresh` end to end
- [ ] Add a test that fails if `/auth/refresh` ever 401s on a token
      minted by the same process's `login` call, catching a future
      re-introduction of this class of drift

## Related Issues
- [[CLUBZERO-2026-09-28-refresh-token-endpoint-cannot-ever-succeed]] —
  this bug was masking the fact that endpoint's other fix was already
  correct.

## References
- `club-zero-backend/app/routers/auth.py`
- `club-zero-backend/app/security.py`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.
