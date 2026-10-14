# Mixing `Depends(OAuth2PasswordRequestForm)` With a Sibling `Form()` Parameter Silently Breaks Login

**Date:** 2026-10-12
**Project:** MARITCHO
**Environment:** Development (caught by a new test before ever reaching staging/production)
**Severity:** High (would have broken every login request in production had it shipped untested)
**Status:** Resolved

## Summary
While adding an optional `role` form field to `POST /token` (so the mobile app's Landing-screen role picker could actually create a `WORKER` account, not just `BUYER`), adding `role: RoleEnum = Form(default=RoleEnum.BUYER)` as a sibling parameter alongside the existing `form_data: OAuth2PasswordRequestForm = Depends()` caused every request to `/token` to fail with a `422` claiming `password` was missing — even when `password` was present in the submitted form body.

## Symptoms
- `POST /token` with a valid form body (`username`, `password`, `role`) returned `422 Unprocessable Entity`: `{"detail": [{"type": "missing", "loc": ["body", "password"], "msg": "Field required", "input": None}]}`.
- The reported missing field (`password`) was present in the request; `input: None` was the tell that the server-side form parser was reading an already-exhausted/empty body, not that the client omitted the field.
- Reproduced identically via `httpx.AsyncClient` in a test and via a raw ASGI test client — ruled out anything client-side (encoding, content-type) immediately.

## Environment Details
- **Server/Host:** local dev / CI test run
- **Services Affected:** `backend-api`, `POST /token` (login) — the only endpoint using `OAuth2PasswordRequestForm`
- **Related Components:** `app/apps/accounts/interface_adapters/router.py::login_for_access_token`
- **Time First Observed:** 2026-10-12, first test run after adding the `role` field

## Investigation Steps

### 1. Initial Diagnosis
Ran the new test directly against the ASGI app (bypassing httpx/network entirely) and got the identical 422 — confirmed the bug was entirely server-side, in FastAPI's request parsing, not a test-client artifact.

### 2. Root Cause Analysis
`OAuth2PasswordRequestForm` is itself a FastAPI dependency class that reads the request body as form data (`await request.form()`) to populate its own fields. Starlette's `Request.form()` is backed by a stream that can only be consumed once per request (it's not idempotent/cached the way `Request.json()` effectively is via `_body` caching in all versions tested). Adding a second, independent `Form(...)`-declared parameter in the same handler caused FastAPI to attempt a second body-stream read for that parameter, which raced against or followed the first read, leaving the form data empty by the time required fields were being validated.

### 3. Key Findings
- This is **not** a documented, obvious incompatibility — plenty of FastAPI code mixes multiple plain `Form(...)` parameters in one handler without issue (those share one parse). The problem is specific to mixing a `Depends()`-wrapped form-parsing dependency *class* (`OAuth2PasswordRequestForm`) with an *additional sibling* `Form(...)` parameter declared directly on the handler.
- The fix: drop `OAuth2PasswordRequestForm` entirely and declare all needed fields (`username: str = Form()`, `password: str = Form(default="")`, `role: RoleEnum = Form(default=RoleEnum.BUYER)`) as plain, independent `Form()` parameters on the handler. This parses correctly (one shared body read across all of them) and is functionally identical for clients (still a form-urlencoded POST with `username`/`password` fields) — the only loss is Swagger UI's "Authorize" button auto-detecting the OAuth2 password flow shape, a cosmetic docs-UI convenience, not a functional requirement for this mock/dev-only login endpoint.

## Root Cause
FastAPI/Starlette's request body stream is single-read; `OAuth2PasswordRequestForm`'s own internal form-parsing `Depends()` and a sibling `Form()` parameter on the same handler each attempt to read that stream independently, so the second reader gets nothing — surfacing as a spurious "field missing" validation error on whichever field(s) only the second reader was responsible for.

## Prevention / Rule
**Guardrail:** Never add a plain `Form(...)` parameter to a handler that also depends on `OAuth2PasswordRequestForm` (or any other dependency class that itself parses the request body as form data) — either declare every field as its own independent `Form(...)` parameter, or keep `OAuth2PasswordRequestForm` and read any extra fields by accessing the raw `Request` object's already-parsed form inside the handler body instead of as a second FastAPI-injected parameter. Call this out explicitly in a code-review checklist item for any FastAPI form-body endpoint touched again.

This closes the gap because the failure mode is non-obvious (a correct-looking request gets rejected for a field that scopes to the *wrong* dependency), and a reviewer scanning the diff for "did they handle the new field" would see a reasonable-looking `Form(default=...)` addition and not flag it — the bug only surfaces at actual request time, which is exactly why a test (not just a type-checker or linter) caught it here.

## Solution

### Immediate Fix
Replaced:
```python
form_data: OAuth2PasswordRequestForm = Depends(),
role: RoleEnum = Form(default=RoleEnum.BUYER),
```
with:
```python
username: str = Form(),
password: str = Form(default=""),
role: RoleEnum = Form(default=RoleEnum.BUYER),
```
and updated the function body to use `username` directly instead of `form_data.username`.

### Long-term Fix
None needed beyond the guardrail above — this is the only endpoint in the project using `OAuth2PasswordRequestForm`.

## Prevention
- [x] Code changes required (done — see Immediate Fix)
- [x] Test added (`tests/test_accounts.py`, which caught this before merge)
- [ ] Documentation to update (add the guardrail above to a shared FastAPI-specific engineering note if this pattern recurs on another project)
- [ ] Monitoring/alerts to add (n/a — caught entirely by the new test)

## References
- `docs/architecture/openapi.yaml` — `/token` now documents the explicit `username`/`password`/`role` form fields
- `docs/architecture/database_schema_design.md` §12 — "Account Role at Signup"

---

**Resolved By:** Claude Code (mobile wireframe / backend-contract review session)
**Time to Resolution:** ~10 minutes (test failure → isolated to server-side via direct ASGI call → root-caused via Starlette's single-read body stream → fixed and reverified)
