# Harness error-reporting middleware discarded every already-handled exception's message

**Date:** 2026-10-05
**Project:** HBEC
**Environment:** Production (Agentic Harness, both the unsuffixed live containers and the blue/green pair)
**Severity:** Medium
**Status:** Resolved

## Summary
Every 4xx/5xx response the Harness produced via a caught-and-reraised
`HTTPException` (i.e. the handler already did the right thing and wrote a
useful `detail` string) was logged into `system_error_logs` with a hardcoded
blank `error_message`. Only genuinely unhandled exceptions (the `except
Exception` branch at the top of the middleware) carried a real message. This
made every already-diagnosed error in the tracker look like an opaque,
contentless `HTTP500`/`HTTP422`/etc., discarding exactly the debugging
information the handler had gone out of its way to produce.

## Symptoms
- `POST /api/v1/admin/papers/upload` logged as `500 HTTP500` with a
  completely empty `error_message`, even though the route's own `except
  Exception` handler builds `detail=f"Upload processing failed:
  {type(exc).__name__}: {exc}"` — a real message that never reached the log.
- Any other already-handled `raise HTTPException(...)` in the harness (422s,
  413s, 503s) has the same gap, not just this one route.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** `hbec-harness` (all three: unsuffixed, `-blue`, `-green` — shared middleware)
- **Related Components:** `app/api/middleware/error_reporting.py`'s `SystemErrorReportingMiddleware`
- **Time First Observed:** found 2026-10-05 while triaging `system_error_logs` via the new `hbec-errors-mcp` tool

## Investigation Steps

### 1. Initial Diagnosis
A `system_error_logs` row for `POST /api/v1/admin/papers/upload` showed
`error_type=HTTP500` and a blank `error_message`. The upload route's own
exception handler (`app/admin/router.py`) was read first and already builds a
non-empty, debuggable detail string — ruling out the handler as the source.

### 2. Root Cause Analysis
```python
# app/api/middleware/error_reporting.py, before the fix:
if response.status_code >= 400 and response.status_code not in _EXCLUDED_STATUS_CODES:
    _dispatch_report(
        ...,
        error_type=f"HTTP{response.status_code}",
        error_message="",   # hardcoded, never reads the response body
        ...,
    )
```
This branch runs whenever `call_next` returns a response object instead of
raising (i.e. any `HTTPException` already converted to a response by
FastAPI's own exception handling before this middleware sees it) — confirmed
`error_type="HTTP500"` only ever comes from this literal f-string, never from
`type(exc).__name__`, which is what the other branch (genuinely unhandled
exceptions) uses.

### 3. Key Findings
- `response` from `call_next` in `BaseHTTPMiddleware` is a streaming wrapper
  even for an already-built `JSONResponse` — its body must be drained to read
  it, and the response rebuilt from the drained bytes so the real client
  still receives it unchanged.

## Root Cause
The middleware's handled-response branch never looked at the response body at
all, discarding the `detail` field of every FastAPI `HTTPException` for every
4xx/5xx that wasn't a raw unhandled exception.

## Prevention / Rule
**Guardrail:** `test_error_reporting_middleware.py`'s
`test_a_422_is_reported_with_the_request_payload` now also asserts
`kwargs["error_message"] == "bad input"` (the route's own detail string) and
that the real client-visible response body is unchanged after the fix —
catching any future regression that reintroduces a blank `error_message` for
an already-handled exception.

## Solution

### Immediate Fix
`app/api/middleware/error_reporting.py`: drain `response.body_iterator`,
parse it as JSON, pull `detail` into `error_message` (truncated to
`_MAX_ERROR_MESSAGE_LEN`), then rebuild the `Response` from the drained bytes
(dropping the stale `content-length` header so it's recomputed) so the real
caller's response is byte-identical to before.

### Long-term Fix
None needed — this was the complete fix.

## Prevention
- [x] Code change applied
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Test coverage added (`test_error_reporting_middleware.py`)

## Related Issues
- Found while triaging the backlog of `system_error_logs` entries surfaced by
  the new `hbec-errors-mcp` tool, same session as the Redis read-only-replica
  incident (`HBEC-2026-10-05-redis-stuck-readonly-replica-since-sentinel-switched-off.md`).

## References
- `app/api/middleware/error_reporting.py`

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Same session as discovery
