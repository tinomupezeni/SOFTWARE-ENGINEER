# `/auth/refresh` can never issue a valid refresh — login never produces a `type: refresh` token, and `refresh` mints no new access token either

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** Medium (dead/broken code path — not currently called by the mobile client, but would fail immediately if wired up)
**Status:** Investigating (found during a codebase read; not yet fixed)

## Summary
`club-zero-backend/app/routers/auth.py`'s `/auth/refresh` endpoint
decodes the submitted token and rejects it unless its payload has
`"type": "refresh"`. But `create_access_token()` in
`club-zero-backend/app/security.py:18-23` — the only place tokens are
ever minted — never sets a `type` claim at all, and `POST /auth/login`
only ever returns a single `access_token`, never a separate refresh
token. So no token this backend has ever issued can pass the `/refresh`
endpoint's own check; every call to it would 401 with "Invalid token
type". Separately, even if that check were bypassed, the handler's
success path doesn't mint a new access token — it echoes the same
refresh token back as the `access_token` (see the `# Adjust to your
token factory` comment in the code), so the endpoint is a stub in two
independent ways. This is currently dormant rather than user-facing: the
Flutter client's `AuthProvider`/`AuthService` never calls `/auth/refresh`.

## Symptoms
- None visible yet — the mobile app doesn't call this endpoint. This is
  a latent defect that would surface the moment token-refresh is wired
  up client-side (necessary for the app to survive past the 7-day
  access-token expiry in `security.py:8` without forcing a re-login).

## Environment Details
- **Server/Host:** Local dev (FastAPI backend)
- **Services Affected:** `club-zero-backend/app/routers/auth.py`
  (`refresh_token`, lines 71-86), `club-zero-backend/app/security.py`
  (`create_access_token`, lines 18-23)
- **Related Components:** `club_zero_mobile/lib/services/storage_service.dart`
  already has `saveTokens(accessToken, refreshToken)` plumbing on the
  client side, implying refresh support was intended but never
  completed end-to-end.
- **Time First Observed:** Found during a full codebase read, 2026-09-28.

## Investigation Steps

### 1. Initial Diagnosis
Traced the token lifecycle from `login` → client storage → `/refresh` to
check whether the refresh flow the mobile storage layer anticipates is
actually implemented on the backend.

### 2. Root Cause Analysis
```python
# security.py:18-23 — the only token factory in the codebase
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})   # no "type" claim ever set
    ...

# auth.py:59-68 — login only ever returns one token
access_token = create_access_token(data={"sub": str(user.id)})
return {"access_token": access_token, "token_type": "bearer"}

# auth.py:71-86 — refresh requires a claim nothing ever sets
decoded = jwt.decode(payload.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
if decoded.get("type") != "refresh":
    raise HTTPException(..., detail="Invalid token type")
...
return {"access_token": payload.refresh_token, "token_type": "bearer"}  # not a new token
```

### 3. Key Findings
- The refresh flow was scaffolded (client-side storage, endpoint shape,
  `RefreshRequest` schema) but never connected: no code path anywhere
  produces a token with `type: refresh`.
- `auth.py` imports `jwt`/`JWTError` from `jose` for this endpoint, while
  `security.py` uses `PyJWT`'s `jwt.encode` for token creation — both
  are HS256-compatible so this isn't itself a bug, but it's worth
  normalizing to one JWT library to avoid future confusion.

## Root Cause
The refresh-token feature is incomplete: the token-minting side
(`create_access_token`) and the token-consuming side (`/auth/refresh`)
were built independently and never reconciled to agree on what a
"refresh token" actually looks like.

## Prevention / Rule
**Guardrail:** Before wiring the Flutter client to call `/auth/refresh`,
add a backend test that does a real `login` → `refresh` round trip
(register, login, POST the returned access token — and, once
implemented, a real refresh token — to `/auth/refresh`) and asserts a
*new*, distinct access token comes back. That test cannot pass until
`login` actually issues a `type: refresh` token and `refresh_token()`
actually mints a new access token, which forces the two sides to agree.

## Solution

### Immediate Fix
Not yet applied — logging this during a read-only codebase review.

### Long-term Fix
- Add a second `create_refresh_token()` (longer-lived, `type: "refresh"`
  claim) in `security.py`.
- Return both `access_token` and `refresh_token` from `POST /auth/login`.
- Have `POST /auth/refresh` call `create_access_token()` for a genuinely
  new access token instead of echoing the input back.

## Prevention
- [ ] Implement a real refresh-token factory and return it from `/login`
- [ ] Fix `/auth/refresh` to mint a new access token
- [ ] Add a login→refresh round-trip test
- [ ] Documentation to update

## Related Issues
- None filed yet.

## References
- `club-zero-backend/app/routers/auth.py`
- `club-zero-backend/app/security.py`
- `club_zero_mobile/lib/services/storage_service.dart`

---

**Resolved By:** Found by Claude (Sonnet 5) during a full codebase read for tinotendamupezeni@thuthuka.tech; not yet fixed.
**Time to Resolution:** N/A — open
