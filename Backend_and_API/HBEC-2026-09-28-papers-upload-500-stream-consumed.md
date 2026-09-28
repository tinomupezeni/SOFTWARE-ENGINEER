# papers/upload 500'd on Every Call — HMAC Check Couldn't Read a Multipart Body

**Date:** 2026-09-28
**Project:** HBEC
**Environment:** Staging (reported live; same code path runs in production)
**Severity:** Critical
**Status:** Resolved

## Summary
User report: "papers uploaded on admin, but nothing was retrieved from
it" — a 500 on every attempt. `POST /api/v1/admin/papers/upload`
(Agentic Harness) failed every single call with `RuntimeError: Stream
consumed`, confirmed via 15+ identical entries in Admin Backend's
`system_error_logs` between 2026-09-28 08:48–08:55 UTC. Root cause:
FastAPI's own `File()`/`Form()` parsing (needed for the upload's
`UploadFile`) always runs before a same-endpoint `Depends()` callable
gets its turn, and multipart parsing drains Starlette's request stream
without ever populating `Request._body` — it only flips
`Request._stream_consumed` to `True`. `_verify_admin_hmac`'s later
`await request.body()` (needed to check the HMAC signature over the
exact bytes) checks that flag before ever calling `receive()` again, so
it raised immediately. No admin-uploaded paper could ever be processed.

## Symptoms
- Every `POST /api/v1/admin/papers/upload` returns 500.
- The admin dashboard shows the upload failed; no paper, no questions,
  nothing retrievable — matching the report exactly.
- No other harness endpoint showed this failure (confirmed: only
  `papers/upload`'s error rows in `system_error_logs`), because it's the
  only harness route combining a `File()`/`Form()` parameter with a
  `Depends()` that reads the raw body.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-harness-staging` (same code path runs
  unpatched in production until its own next deploy)
- **Services Affected:** Agentic Harness `/papers/upload`
- **Related Components:** `app/shared/auth.py` (`_verify_admin_hmac`,
  `_verify_internal_hmac`), `app/admin/router.py` (`upload_paper`),
  `app/api/middleware/error_reporting.py`
- **Time First Observed:** Reported 2026-09-28; error rows date back to
  at least 08:48 UTC the same day

## Investigation Steps

### 1. Initial Diagnosis
No live container logs predating the report (containers had been
recreated during an unrelated deploy earlier the same session), but
Admin Backend keeps a persistent `system_error_logs` table fed by every
service's own error-reporting middleware. Queried it directly:
```sql
SELECT created_at, service, path, method, status_code, error_type, left(error_message, 150)
FROM system_error_logs
WHERE status_code = 500 AND path ILIKE '%paper%'
ORDER BY created_at DESC LIMIT 15;
```
15 identical rows: `harness`, `POST /api/v1/admin/papers/upload`, 500,
`RuntimeError`, `Stream consumed`.

### 2. Root Cause Analysis
Pulled the full `stack_trace` column for one row — the failure was inside
`app/shared/auth.py:184`, `_verify_admin_hmac`'s
`body=await request.body()`, raised from Starlette's
`Request.stream()`: `if self._stream_consumed: raise RuntimeError("Stream
consumed")`.

Reproduced in isolation (no harness code, no middleware) with a minimal
FastAPI app: an endpoint with `file: UploadFile = File(...)` plus a
`Depends()` callable that reads `await request.body()` crashes
identically, regardless of which parameter is declared first in the
function signature — proving this is not specific to any middleware in
the harness's stack, but an inherent FastAPI/Starlette ordering fact:
form-parsing for `File()`/`Form()` parameters always runs before a
same-level `Depends()` callable, and multipart parsing never populates
`Request._body`.

Confirmed a **replayable `receive()` wrapper cannot fix this**: built one
(caches the real ASGI messages, replays the full body on every call) and
the crash still reproduced identically. `Request.stream()`'s guard
(`self._stream_consumed`) is checked *before* `receive()` is ever called
again — it's per-object Python state, not tied to whether the underlying
channel still has data.

### 3. Key Findings
- `_verify_admin_hmac`'s own docstring already documented an assumption
  ("Starlette caches the body, so form parsing still sees it") that was
  only true in the *other* order (HMAC check first, form-parsing second)
  — the actual FastAPI dependency-resolution order runs the opposite way
  in practice, silently invalidating that assumption without anyone
  noticing until a real upload was attempted.
- The one thing every `Request` object built for a single HTTP call
  shares by reference is the ASGI `scope` dict — not `Request._body`,
  which is per-object.
- `SystemErrorReportingMiddleware` (the harness's own error-reporting
  layer) also unconditionally read `request.body()` for every
  POST/PUT/PATCH to capture a JSON payload for its error log — for a
  multipart body this always failed `json.loads` silently (every crashed
  row's `payload` column was `{}`), so it cost something (one more
  read racing the same stream) for zero benefit on this class of request.

## Root Cause
FastAPI's internal `File()`/`Form()` parsing consumes the request stream
before a same-endpoint `Depends()` callable runs, and multipart parsing
never populates the one cache (`Request._body`) that would let a later
raw-body read succeed — an inherent library ordering fact, not a
one-off bug in `_verify_admin_hmac` itself, though that function was the
first (and only) code in this codebase to combine both needs on one
endpoint.

## Prevention / Rule
**Guardrail:** Any endpoint that combines a `File()`/`Form()` parameter
with a dependency that needs the raw, exact request bytes (HMAC/signature
verification, checksum validation, anything hashing "the body as sent")
must read that raw body via `app.api.middleware.body_cache.get_raw_body()`,
never `request.body()` directly. `test_body_cache_middleware.py` pins
this with a test that reproduces the original crash with the middleware
absent, so a future refactor that accidentally drops
`BodyCachingMiddleware` from the app fails a test rather than 500ing on
the next real admin upload.

## Solution

### Immediate Fix
- New `app/api/middleware/body_cache.py`: `BodyCachingMiddleware` (a
  plain ASGI middleware, not `BaseHTTPMiddleware` — it must run before
  FastAPI's routing/dependency machinery ever sees the request) drains
  the body once from the real incoming ASGI messages and, the instant
  it's fully read, republishes the raw bytes into `scope["state"]` —
  visible to every `Request` object built from that same `scope`,
  regardless of which one reads it first. `get_raw_body(request)` reads
  that cache, falling back to a plain `request.body()` when the
  middleware never ran (so it degrades safely in a test app or any
  future non-body-bearing method).
- Registered as the true outermost middleware in `app/main.py` (Starlette
  wraps in reverse registration order — added last so it wraps
  everything, including `SystemErrorReportingMiddleware`).
- `_verify_admin_hmac` and `_verify_internal_hmac` (`app/shared/auth.py`)
  now call `get_raw_body()` instead of `request.body()` directly.
- `SystemErrorReportingMiddleware` now only reads the body for
  `application/json` content types — a multipart body was never going to
  parse as JSON anyway (confirmed: every crashed row's `payload` was
  already `{}`), so this removes a pointless extra read. Verified this
  change alone was **not** sufficient to fix the crash (the deeper
  FastAPI ordering issue remained) before adding `BodyCachingMiddleware`.
- Verified on staging with a real signed multipart request (v2 a2h HMAC,
  built and sent from inside the harness container itself): before the
  fix, 15 consecutive `500 RuntimeError: Stream consumed`; after
  rebuilding and recreating `hbec-harness-staging`, the same call
  returned a proper `415` business-logic rejection (the test file's fake
  content correctly failed the "does this look like an exam paper" check)
  — the crash is gone, and the pipeline genuinely parses the upload far
  enough to make that content judgement.

### Long-term Fix
None needed beyond the fix itself — `get_raw_body()` is now the
documented, tested pattern for any future endpoint needing both a file
upload and a raw-body check.

## Prevention
- [x] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none; `system_error_logs` already
  surfaced this immediately and precisely
- [x] Documentation to update — `body_cache.py`'s module docstring and
  `_verify_admin_hmac`'s docstring both now state the real mechanism
- [x] Code changes required — done, staging verified; production still
  needs the next harness deploy to pick this up

## Related Issues
- None directly, though the same session's cancel_subscription fix
  (`HBEC-2026-09-28-cancel-subscription-500-after-successful-cancel.md`)
  was found the same way: a real, unrelated 500 surfaced while manually
  verifying a different feature on staging.

## References
- `AGENTIC_HARNESS/app/api/middleware/body_cache.py` (new)
- `AGENTIC_HARNESS/app/shared/auth.py` (`_verify_admin_hmac`,
  `_verify_internal_hmac`)
- `AGENTIC_HARNESS/app/api/middleware/error_reporting.py`
- `AGENTIC_HARNESS/app/main.py` (middleware registration order)
- `AGENTIC_HARNESS/tests/unit/test_body_cache_middleware.py` (new — the
  regression test, including one that reproduces the original crash with
  the middleware deliberately absent)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as report; staging verified,
production still needs the next harness deploy
