# A Body-Caching Fix Broke Every SSE Stream in Production Ten Minutes After Deploy

**Date:** 2026-09-28
**Project:** HBEC
**Environment:** Production (live incident, real users affected)
**Severity:** Critical
**Status:** Resolved

## Summary
The same-day fix for `papers/upload`'s `RuntimeError: Stream consumed`
(see `HBEC-2026-09-28-papers-upload-500-stream-consumed.md`) shipped to
production as part of a 72-commit catch-up promotion. Within about ten
minutes, the user reported live: "friday doesnt seem to be reposnding" —
Friday (the harness's companion chat) stopped returning any response,
confirmed by a pasted screenshot showing two unanswered "hi" messages.
Root cause: `BodyCachingMiddleware`'s wrapped `receive()` fabricated a
synthetic `{"type": "http.request", ...}` message on every call after a
request body had been drained, instead of delegating to the real
`receive()`. That is invisible for an ordinary quick request/response,
but every long-lived streaming response (SSE, which is exactly how Friday
streams its replies) depends on Starlette's own disconnect-watching
machinery calling `receive()` repeatedly for as long as the connection
stays open — and that machinery only tolerates a real message or a real
client disconnect. The fabricated message violated that contract and
raised `RuntimeError: Unexpected message received: http.request` almost
immediately, killing every streaming response server-side.

## Symptoms
- Friday's chat UI shows the student's message sent, then nothing —
  the assistant never replies, indefinitely.
- Not specific to Friday's business logic: any streaming (SSE) endpoint
  behind this middleware would show the identical failure, since the
  crash is in generic ASGI/Starlette plumbing, not in Friday's own code.
- The browser/nginx side reported the request as a plain `200`, not an
  error — nginx's access log showed
  `POST /harness-stream/api/v1/friday/chat/stream" 200 5` (200 status,
  a 5-byte body), which is why this looked like "no response" rather
  than an obvious failure: nothing 4xx'd or 5xx'd anywhere in the chain
  a casual glance would check.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-harness` (production); reproduced
  first on `hbec-harness-staging` before promoting the fix back
- **Services Affected:** Agentic Harness — any streaming (SSE) endpoint,
  Friday's chat being the one actually in active use
- **Related Components:** `app/api/middleware/body_cache.py`
  (`BodyCachingMiddleware`), `app/api/middleware/error_reporting.py`
  (`SystemErrorReportingMiddleware`, a `BaseHTTPMiddleware` — its
  background disconnect-watcher is what actually called the broken
  `receive()` repeatedly)
- **Time First Observed:** 2026-09-28, ~10 minutes after
  `full-catchup-promotion-20260928` (see `.PROMOTION_NOTES.txt`)

## Investigation Steps

### 1. Initial Diagnosis
User report gave no error, just "not responding." Checked Admin
Backend's `system_error_logs` for anything in the last 30 minutes —
nothing for Friday's endpoints at all (the crash happens deep enough in
ASGI plumbing that it never reaches `SystemErrorReportingMiddleware`'s
own exception-catching `except Exception` branch cleanly — see below for
why). Checked harness's own structured logs for `friday` — only
event-bus subscription lines from container startup, no request activity
at all for the actual chat call.

### 2. Root Cause Analysis
Traced the actual network path instead of guessing: the student
frontend's own nginx access log (`docker logs hbec-student-frontend`)
showed the real requests and their real status:
```
POST /api/ai/chat/authorize-stream/ HTTP/1.1" 200 803
POST /harness-stream/api/v1/friday/chat/stream HTTP/1.1" 200 5
```
A 200 with a 5-byte body is not a real SSE response (Friday's stream
carries retrieval-step metadata, multiple token chunks, and a `done`
event — hundreds of bytes minimum). That pointed straight at the harness
container's own log at that timestamp, which had the real traceback:
```
File ".../starlette/middleware/base.py", line 57, in wrapped_receive
    raise RuntimeError(f"Unexpected message received: {msg['type']}")
RuntimeError: Unexpected message received: http.request
```
Read back `BodyCachingMiddleware`'s `cache_and_relay_receive` closure
(added the same day for the `papers/upload` fix): once the body was
fully drained, it unconditionally returned
`{"type": "http.request", "body": b"", "more_body": False}` on every
subsequent call, forever — instead of forwarding to the real, underlying
`receive()`. `SystemErrorReportingMiddleware` (`BaseHTTPMiddleware`)
runs a background task (`receive_or_disconnect`) that calls `receive()`
in a loop for as long as a streaming response is open, specifically to
notice a real client disconnect; getting a synthetic `http.request`
message there instead of `http.disconnect` (or continued waiting) is
exactly the case Starlette's own code refuses.

### 3. Key Findings
- The original design reasoned "a real client only sends the body once,"
  which is true — but it does not follow that nothing should ever call
  `receive()` again. Long-lived responses call it continuously to watch
  for disconnect, and the ASGI-correct behavior for "nothing more to
  give you from the body" is to delegate to the real channel (which
  correctly yields `http.disconnect` when the client actually goes away),
  not to keep answering with a fake message.
- The fix that introduced this bug had already been unit-tested (5 tests
  covering the multipart-upload case it was built for) and passed —
  because none of those tests exercised a long-lived streaming response.
  The regression only existed on a code path nothing had tested yet.
- The failure was nearly invisible by every routine signal: no 5xx in
  nginx, no entry in `system_error_logs` (the crash happens inside
  Starlette's own background task, one layer removed from where
  `SystemErrorReportingMiddleware`'s own `except Exception` block can
  catch and report it), and no obvious harness log line without reading
  the raw container output around the exact timestamp.

## Root Cause
`BodyCachingMiddleware.cache_and_relay_receive()` fabricated a synthetic
ASGI message after the body was fully read, instead of delegating to the
real `receive()` — correct only for the narrow case that motivated the
fix (a quick request/response with no further `receive()` calls), and
silently wrong for the much more common case in this codebase of a
long-lived SSE response, which every companion/chat surface uses.

## Prevention / Rule
**Guardrail:** `tests/unit/test_body_cache_middleware.py` now includes
`test_long_lived_streaming_response_survives_body_caching_middleware`,
which stacks the exact same middleware pair the harness runs
(`SystemErrorReportingMiddleware` + `BodyCachingMiddleware`) around a
real `StreamingResponse` that yields multiple chunks with a delay between
them — giving `BaseHTTPMiddleware`'s disconnect-watcher a real chance to
call `receive()` again mid-stream, the exact window the original bug
crashed in. Verified this test fails without the fix (reproducing the
identical `RuntimeError: Unexpected message received: http.request`) and
passes with it. Any future change to `body_cache.py` that reintroduces
this class of bug fails this test before it can reach staging.

## Solution

### Immediate Fix
`cache_and_relay_receive()`: once `drained` is `True`, `return await
receive()` (delegate to the real channel) instead of fabricating a
message. Readers after the first body-reader still get the cached bytes
via `scope["state"]`, never through another `receive()` call, so nothing
needs to be faked at all.

Deployed staging first: rebuilt `hbec-harness-staging`, then verified
with a **real, complete guest SSE conversation** (no test-only
shortcuts) — minted a real guest stream token via
`POST /api/ai/chat/authorize-stream/` (`AllowAny`, no student login
needed) and streamed an actual chat message through
`/harness-stream/api/v1/friday/chat/stream`, receiving the full expected
sequence: a `conversation_id` metadata event, retrieval-step statuses,
several token chunks of real generated text, and a `done` event.

Promoted to production the same way: retagged all 10 canonical images to
the new commit's sha (only harness's content actually changed; the other
9 are byte-identical to the prior tag, retagged anyway to keep every
service on one consistent `TAG` rather than reintroducing the mixed-tag
state the same day's earlier promotion had just cleaned up), recreated
all 16 app services, then repeated the exact same real guest-SSE
verification directly against `student.hbca.tech` — full conversation
streamed correctly. `verify-service-links.sh` and
`check_runtime_secret_drift.py` both clean afterward.

### Long-term Fix
None needed beyond the regression test — the fix itself is a two-line
change once the correct behavior (delegate, don't fabricate) was
understood.

## Prevention
- [x] Configuration changes needed — none
- [ ] Monitoring/alerts to add — worth considering: an alert on harness
  response body size for streaming content-types dropping below a
  reasonable floor would have caught this without waiting for a user
  report
- [x] Documentation to update — `body_cache.py`'s inline comment at the
  fix site explains the disconnect-watching mechanism and why
  fabricating a message is never correct there
- [x] Code changes required — done, staging and production verified

## Related Issues
- Directly caused by, and fixes,
  `HBEC-2026-09-28-papers-upload-500-stream-consumed.md`'s
  `BodyCachingMiddleware` — same file, same day, a second bug in the
  same new code before its first real production traffic exercised the
  streaming path.
- Logged in production's own promotion history as `hotfix-20260928b` in
  `/opt/hbec/.PROMOTION_NOTES.txt`, immediately following
  `full-catchup-promotion-20260928`.

## References
- `AGENTIC_HARNESS/app/api/middleware/body_cache.py`
- `AGENTIC_HARNESS/tests/unit/test_body_cache_middleware.py`
- `AGENTIC_HARNESS/app/api/middleware/error_reporting.py`
  (`SystemErrorReportingMiddleware`, whose disconnect-watcher surfaced
  this)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** ~20 minutes from the user's report to verified
production fix (staging-verified first)
