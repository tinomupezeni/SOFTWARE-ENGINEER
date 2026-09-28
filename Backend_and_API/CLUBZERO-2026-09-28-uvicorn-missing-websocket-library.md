# Every real-time feature (avatars lighting up, live habit updates) silently 404'd — uvicorn had no WebSocket library installed

**Date:** 2026-09-28
**Project:** Club Zero
**Environment:** Development
**Severity:** Critical — the entire real-time layer (the "ambient awareness" mechanic the product is built around) had never worked in this deployment
**Status:** Resolved

## Summary
While testing the mobile app's live dashboard update (a friend's avatar
lighting up when they check in), the Flutter client's WebSocket connection
to `/clubs/{club_id}/ws` failed with "was not upgraded to websocket". The
backend logs showed uvicorn itself printing: `WARNING: No supported
WebSocket library detected. Please use "pip install 'uvicorn[standard]'",
or install 'websockets' or 'wsproto' manually.` — uvicorn was silently
treating every WebSocket upgrade request as a plain HTTP GET that matched
no route, returning a bare 404. `requirements.txt` pinned plain
`uvicorn==0.27.1`, not `uvicorn[standard]`, and neither `websockets` nor
`wsproto` was listed as a separate dependency.

## Symptoms
- Flutter: `WebSocketChannelException: WebSocketException: Connection to
  '...' was not upgraded to websocket`.
- Backend logs: `WARNING: Unsupported upgrade request.` followed by `GET
  /clubs/{id}/ws?token=... HTTP/1.1" 404 Not Found` — no `[accepted]` /
  `connection open` lines at all until this was fixed.
- Every feature depending on the WebSocket — the seats row lighting up
  live, per-habit "Done by" updates, anything relying on
  `app/realtime.py`'s Redis-publish path reaching a connected client —
  had silently never worked in any deployment of this backend, including
  before this session's own changes.

## Environment Details
- **Server/Host:** Local dev (FastAPI backend, docker-compose)
- **Services Affected:** `club-zero-backend/requirements.txt`,
  `app/routers/websockets.py` (the endpoint itself was correctly
  implemented — uvicorn simply never routed requests to it)
- **Time First Observed:** 2026-09-28, while live-testing the dashboard's
  real-time check-in broadcast on a physical device.

## Investigation Steps

### 1. Initial Diagnosis
The Flutter client's WS connection attempt failed immediately; checked
`docker compose logs api` for the corresponding request.

### 2. Root Cause Analysis
```
requirements.txt (before fix):
fastapi==0.110.0
uvicorn==0.27.1        # plain uvicorn — no ASGI websocket protocol implementation bundled
```
uvicorn needs either the `websockets` or `wsproto` package to speak the
WebSocket protocol at all; without one, it falls back to treating an
Upgrade request as ordinary HTTP, which has no matching route.

### 3. Key Findings
- This is completely independent of anything built or changed earlier in
  this session — `app/routers/websockets.py`'s implementation was already
  correct. The dependency was simply never declared.
- Nothing in the existing `pytest` suite (`tests/test_checkins.py` etc.)
  exercises the WebSocket endpoint at all, so this had no automated test
  that could have caught it.

## Root Cause
`requirements.txt` declared plain `uvicorn` instead of `uvicorn[standard]`
(or `websockets`/`wsproto` as an explicit separate dependency), so the
ASGI server had no WebSocket protocol implementation to use.

## Prevention / Rule
**Guardrail:** Add a backend test that opens a real WebSocket connection
to `/clubs/{id}/ws` (using the `websockets` package, same as the manual
verification here) and asserts a `check_in_completed` event round-trips.
A test at the HTTP-request layer alone (like the existing check-in tests)
cannot catch this class of bug — only a test that actually attempts the
protocol upgrade would fail identically to how the real client failed.

## Solution

### Immediate Fix
Changed `requirements.txt`: `uvicorn==0.27.1` → `uvicorn[standard]==0.27.1`,
rebuilt the Docker image. Verified: `websockets-17.1` installed
(confirmed in the pip install log), and a direct Python
`websockets.connect()` test against the live container now connects,
triggers a check-in over REST, and receives the `check_in_completed`
broadcast within the WebSocket — full round trip confirmed working.

### Long-term Fix
Add the WebSocket round-trip test described above to the `pytest` suite
so this can't silently regress again.

## Prevention
- [x] Switch to `uvicorn[standard]` in `requirements.txt`
- [x] Verify a real WebSocket round trip against the live stack
- [ ] Add an automated WebSocket test to the `pytest` suite

## Related Issues
- None filed yet for the missing WS test coverage — tracked as a
  follow-up in `/home/shadowe/Projects/SharedHQ/DEVLOG.md`.

## References
- `club-zero-backend/requirements.txt`
- `club-zero-backend/app/routers/websockets.py`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-09-28.
