# Harness `BodyCachingMiddleware` Buffers Every Request Body With No Size Cap

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`) before merge
**Severity:** High (memory-exhaustion / DoS vector, applies to every POST/PUT/PATCH on the harness)
**Status:** Investigating (flagged in PR review, not yet fixed on `experimental`)

## Summary
The PR's merge resolution keeps master's `BodyCachingMiddleware`
(`AGENTIC_HARNESS/app/api/middleware/body_cache.py`) over experimental's
`SignedBodyMiddleware`, because it independently fixes a real bug (streaming
SSE responses broke when a synthetic `http.request` was fabricated — see
`HBEC-2026-09-28-body-caching-middleware-broke-every-sse-stream.md`). But
`BodyCachingMiddleware` itself has **no size cap at all**:
`cache_and_relay_receive()` (lines 64-92) unconditionally appends every chunk
of every body-bearing request into an in-memory `bytearray`
(`cached_body.extend(message.get("body", b""))`, line 88), for **every**
POST/PUT/PATCH request to the harness, not just signed/admin-upload ones.

The removed `SignedBodyMiddleware` refused any signed body over
`MAX_SIGNED_BODY + 1 MiB` with an early `413`, before buffering anything. The
PR description acknowledges "the oversize-upload 413 ... is gone" but frames
it as scoped to uploads; it is not — it applies to every body-bearing
endpoint on the harness.

## Symptoms
None in production yet — found during PR review before merge.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (FastAPI/uvicorn, port 8080)
- **Services Affected:** every endpoint accepting POST/PUT/PATCH
- **Related Components:** `app/api/middleware/body_cache.py`,
  `app/admin/services/upload_pipeline.py` (`spooled_upload`,
  `MAX_UPLOAD_BYTES` — this check runs only after the full body has already
  been parsed/buffered, so it bounds disk usage, not the earlier in-memory copy)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
PR review (recall-biased, 8-angle finder pass) flagged the removed-behavior
gap between experimental's `SignedBodyMiddleware` and master's
`BodyCachingMiddleware` kept by the merge.

### 2. Root Cause Analysis
Read `body_cache.py` directly: the ASGI `receive()` wrapper accumulates every
chunk into `cached_body` with no length check, and only writes it to
`scope["state"]` once the stream fully drains. No upstream reverse-proxy
(Caddy) body-size limit fronts the harness either.

### 3. Key Findings
- `BodyCachingMiddleware` applies to **all** body-bearing requests, not just
  signed/admin ones — broader exposure than the PR description states.
- `MAX_UPLOAD_BYTES` in `spooled_upload` cannot help: by the time it would
  see an oversize file, Starlette's multipart parsing has already driven the
  ASGI receive loop to completion, so the full body is already buffered once.

## Root Cause
Replacing `SignedBodyMiddleware` with `BodyCachingMiddleware` fixed the SSE
bug but dropped the only size enforcement that ran *before* buffering,
without adding an equivalent cap to the replacement.

## Prevention / Rule
**Guardrail:** add an explicit byte-count cap inside
`cache_and_relay_receive()` (e.g. `MAX_BODY_BYTES` checked on each
`cached_body.extend(...)`, raising/rejecting with a `413` before continuing
to buffer) so no in-memory middleware can ever accumulate an unbounded body,
independent of any route-level check that runs later.

This closes the gap at the layer that actually does the unbounded
accumulation, rather than relying on a downstream check that only runs after
the damage (the full in-memory copy) is already done.

## Solution

### Immediate Fix
None yet — flagged in PR #51 review for the author to address before merge.

### Long-term Fix
Add a size cap to `BodyCachingMiddleware` itself (see Guardrail above), and
consider a reverse-proxy-level `client_max_body_size` as defense in depth.

## Prevention
- [ ] Add `MAX_BODY_BYTES` cap to `BodyCachingMiddleware`
- [ ] Add a regression test sending an oversized body to a plain (non-upload)
      endpoint and asserting an early rejection, not an OOM
- [ ] Consider a Caddy/front-proxy body-size limit as defense in depth

## Related Issues
- `HBEC-2026-09-28-body-caching-middleware-broke-every-sse-stream.md` (the
  bug this middleware itself was introduced to fix)
- `HBEC-2026-09-28-papers-upload-500-stream-consumed.md`

## References
- `AGENTIC_HARNESS/app/api/middleware/body_cache.py`
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending author fix before merge
