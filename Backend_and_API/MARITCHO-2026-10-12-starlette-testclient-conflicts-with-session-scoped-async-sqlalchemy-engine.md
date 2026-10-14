# Starlette's Synchronous TestClient Breaks a Session-Scoped Async SQLAlchemy Engine (Can't Automate WebSocket Tests This Way)

**Date:** 2026-10-12
**Project:** MARITCHO
**Environment:** Development (test suite only — never reached production, no runtime impact)
**Severity:** Low (blocked one test's automation; the feature itself works, verified by other means)
**Status:** Resolved (worked around — root cause not fixed, documented as a known limitation)

## Summary
While adding the first WebSocket endpoint this project has ever had (real-time chat, per-job), the natural way to test it — Starlette's synchronous `TestClient`, which has native `.websocket_connect()` support that the project's existing async `httpx.AsyncClient` fixture (via `ASGITransport`) cannot provide at all — reproducibly broke the shared, session-scoped async SQLAlchemy engine with `RuntimeError: ... got Future ... attached to a different loop`, on the very first database query, even in a test run in complete isolation.

## Symptoms
- `RuntimeError: Task <Task pending name='anyio.from_thread.BlockingPortal._call_func' ...> got Future <Future pending cb=[BaseProtocol._on_waiter_completed()]> attached to a different loop`, raised deep inside `asyncpg`'s connection-pool health check (`do_ping`) on the very first ORM query (`PersonRepository.get_by_phone`, called from the mock login endpoint).
- Reproduced identically whether the failing test ran alone (`pytest tests/test_messaging.py::test_websocket_...`) or as part of the full suite — ruling out state leaking in from other tests.
- Explicitly calling `await engine.dispose()` (wrapped in `asyncio.run(...)`) immediately before constructing the `TestClient`, and again afterward, did **not** resolve it — the failure recurred on the very first connection checkout after disposal, not just on a reused stale one.

## Environment Details
- **Server/Host:** local dev / CI test run (`pytest`, Python 3.14, SQLAlchemy 2.x async engine with `asyncpg`)
- **Services Affected:** test suite only (`tests/test_messaging.py`) — no application runtime impact
- **Related Components:** `app/core/database.py` (module-level `engine`/`AsyncSessionLocal`, constructed once at import time), `starlette.testclient.TestClient` (drives the ASGI app via an `anyio.from_thread.BlockingPortal`, i.e. its own thread with its own event loop)
- **Time First Observed:** 2026-10-12, first attempt to write an automated test for `WS /jobs/{job_id}/ws`

## Investigation Steps

### 1. Initial Diagnosis
Confirmed `httpx` (the library backing every other test's `client` fixture) has no WebSocket support at all — there was never a way to test this endpoint with the existing async test infrastructure. Switched to Starlette's `TestClient`, the standard documented approach for testing FastAPI/Starlette WebSocket routes without a real running server.

### 2. Root Cause Analysis
`app/core/database.py`'s `engine` and `AsyncSessionLocal` are module-level singletons, constructed once at import time and reused for the life of the test process — by design, so every async test shares one connection pool bound to pytest-asyncio's session-scoped event loop. `TestClient` is synchronous by design but drives the async ASGI app underneath via an `anyio.from_thread.BlockingPortal`, which runs the app's coroutines in a **separate thread with its own event loop**. SQLAlchemy's asyncpg dialect bridges sync-looking ORM calls to async code via `greenlet_spawn`; that bridging mechanism, combined with a connection pool whose connections (and in-flight waiter futures) are implicitly tied to a specific event loop, collided with the portal's independent loop the moment a query ran.

### 3. Key Findings
- This is **not** a connection-reuse bug in the ordinary sense (stale pooled connection from a prior test) — the error reproduced on the very first query in complete isolation, meaning the incompatibility is structural: a session-scoped async engine and a `TestClient`-driven request simply cannot safely share a process, not just "cannot share a connection."
- Disposing the engine's pool before and after did not help, which rules out "just needed a clean pool" as the fix and points to the deeper greenlet/anyio-portal interaction rather than stale state.
- The REST side of the same feature (send/list/mark-read, authorization, payload validation) is fully testable with the existing async `client` fixture and is NOT affected — this is specific to needing `TestClient` for WebSocket support.

## Root Cause
Mixing a module-level, session-scoped async SQLAlchemy engine (whose asyncpg connection pool is implicitly bound to one event loop) with Starlette's `TestClient`, which executes the ASGI app's coroutines on a *different* event loop running in its own thread via an `anyio` `BlockingPortal` — the two cannot safely coexist in the same process for a database-backed route, regardless of pool disposal timing.

## Prevention / Rule
**Guardrail:** Don't reach for Starlette's synchronous `TestClient` to test a WebSocket route in a codebase whose async SQLAlchemy engine is a shared, session-scoped singleton (the common pattern for a project that already has a large async `httpx`-based test suite) — it will not coexist safely, and disposing the pool around it is not a reliable fix. If a WebSocket route needs automated coverage in a project built this way, the options are: (a) give the engine a per-test or per-process lifecycle instead of session-scoped (a bigger structural change to the existing test suite, not undertaken here), or (b) verify the route with a genuine out-of-process smoke test (a real server, a real WebSocket client library, real REST calls) instead of an in-process `TestClient`.

This closes the gap by naming the actual incompatible pairing (session-scoped async engine + `TestClient`'s portal-threading model) so the next person doesn't spend time trying pool-disposal timing variations that were already tried and don't work.

## Solution

### Immediate Fix
Verified the feature with a genuine out-of-process smoke test instead of an automated pytest case: a real `uvicorn` server process against the real Postgres/Redis test containers, a plain `httpx.AsyncClient` for the REST setup calls, and the `websockets` library (installed ad hoc into the dev venv for this one verification, not added to the project's dependencies) as the WebSocket client — confirmed a message sent via `POST /jobs/{id}/messages` arrives in real time on an open `/jobs/{id}/ws` connection, and that a non-party's connection attempt is correctly rejected.

### Long-term Fix
Not pursued in this pass — would require restructuring the test suite's engine lifecycle (e.g., a per-test or per-worker engine instead of one process-wide singleton), a change with broad blast radius across 160+ existing tests, not justified for one WebSocket route. Documented as a known limitation in `docs/architecture/adr/008-realtime-chat-via-websockets-and-redis-pubsub.md`'s Consequences section instead.

## Prevention
- [ ] Configuration changes needed (would require the engine-lifecycle restructuring noted above, not undertaken)
- [x] Documentation to update (done — ADR-008 and this entry)
- [ ] Monitoring/alerts to add (n/a — test-suite-only issue)
- [ ] Code changes required (n/a beyond the smoke-test script, which isn't part of the committed test suite)

## Related Issues
- Found while building `docs/architecture/adr/008-realtime-chat-via-websockets-and-redis-pubsub.md`'s feature (the project's first WebSocket route).

## References
- `docs/architecture/adr/008-realtime-chat-via-websockets-and-redis-pubsub.md`
- `app/core/database.py` (the shared engine)
- `tests/test_messaging.py` (documents this limitation in-file, alongside the REST tests that *are* automated)

---

**Resolved By:** Claude Code (chat backend implementation session)
**Time to Resolution:** ~25 minutes (reproduced, tried pool-disposal timing variations, root-caused to the portal/greenlet interaction, pivoted to an out-of-process smoke test instead of continuing to fight it)
