# Notifications stream consumer timed out on every single poll against real Redis

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging (production intentionally untouched)
**Severity:** High (new feature's core reliability path was completely broken from first deploy)
**Status:** Resolved — verified live on staging

## Summary
The new `NOTIFICATIONS` service's `consume_content_stream` Celery task (its
Redis-Streams consumer for system-generated notification events) failed on
every single invocation once deployed against real infrastructure, even
though its own test suite passed 35/35. The task ran every 10s via Celery
beat and errored every 10s.

## Symptoms
- `hbec-notifications-worker-staging` logs showed
  `redis.exceptions.TimeoutError: Timeout reading from redis:6379` on every
  `consume_content_stream` task execution.
- A direct synchronous `redis.Redis.from_url(...).ping()` from inside the
  same container succeeded instantly — basic connectivity was fine, so this
  looked contradictory at first.
- The test suite (35/35 tests) never caught it, because every test that
  exercises the consumer publishes a message to the stream *before* calling
  it — so `XREADGROUP` always has something to return immediately and never
  actually blocks.

## Environment Details
- **Services Affected:** `hbec-notifications-worker-staging`,
  `hbec-notifications-beat-staging`
- **Related Components:** `NOTIFICATIONS/app/notifications/fanout.py`
  (`_consume_content_stream_async` / `_drain`), redis-py 8.1.0
- **Time First Observed:** immediately after first staging deploy of the
  notifications service, 2026-09-14

## Investigation Steps

### 1. Initial Diagnosis
Checked whether the notifications service itself was reachable — `/health`
returned `{"status":"ok"}` from inside the container and via both frontends'
nginx proxies, so the FastAPI process and basic Redis wiring both looked
fine. The failure was isolated to the Celery worker's stream consumer path.

### 2. Root Cause Analysis
Read the full traceback: `asyncio.exceptions.CancelledError` raised inside
`asyncio.timeout()`'s `__aexit__`, converted to `redis.exceptions.TimeoutError`
by `redis/asyncio/connection.py`'s `read_response`. That pointed at a
client-side timeout, not a network problem — confirmed by testing:

```python
import inspect, redis
sig = inspect.signature(redis.asyncio.Redis.__init__)
for name, p in sig.parameters.items():
    if 'timeout' in name:
        print(name, p.default)
# socket_timeout 5
# socket_connect_timeout 5
```

### 3. Key Findings
- `fanout.py` called `XREADGROUP ... BLOCK 0` (block forever, server-side)
  when reading new messages — a normal, idiomatic way to make a blocking
  consumer efficient.
- `redis-py` 8.1.0's `redis.asyncio.Redis` defaults `socket_timeout=5`
  (seconds) — a **client-side** cap on how long it will wait for any reply
  at all, completely independent of the `BLOCK` value sent to the server.
  Older redis-py versions defaulted this to `None` (no client-side timeout),
  so `BLOCK 0` used to work as intended; on 8.1.0 it does not.
- With nothing yet in the brand-new `notification_events` stream, every
  poll waited exactly 5s (the client timeout) and then raised, instead of
  waiting indefinitely (the server-side intent) or returning an empty
  result gracefully.
- The function's own docstring/comment already stated the real intended
  contract — "one invocation always terminates, Beat re-runs every 10s for
  the rest" — which `BLOCK 0` never actually matched anyway, timeout bug or
  not: a 10s beat schedule polling a task that can block forever is already
  a latent design mismatch, just one the version-specific timeout happened
  to surface immediately instead of only under rare timing.

## Root Cause
`BLOCK 0` (infinite server-side block) combined with `redis-py`'s
version-dependent client-side `socket_timeout` default (5s in 8.1.0, `None`
before) is a silent trap: the client abandons the read and raises before
the server-side block duration ever has a chance to matter, and it is
invisible in any test that always has data ready to read.

## Prevention / Rule
**Guardrail:** Never pass `block=0` to an async redis-py `XREADGROUP`/`XREAD`
call without also explicitly setting `socket_timeout=None` (or a value
strictly greater than the block duration) on the client — a code-review /
lint-comment convention for this codebase's Redis Streams consumers. Better
still (what was actually applied here): don't use an infinite block at all
against a task that a scheduler already re-triggers on a short fixed
interval — bound the block well under both the beat interval and whatever
the redis-py version's default client timeout is, so an empty stream is a
normal fast return, not a race between two independently-configured
timeouts.

## Solution

### Immediate Fix
`fanout.py`'s `_drain` — changed `block=0` to `block=1000` (1 second,
comfortably under redis-py's 5s default `socket_timeout` and small relative
to the 10s beat interval). Rebuilt and force-recreated
`notifications-worker`/`notifications-beat`/`notifications` on staging;
confirmed via logs that `consume_content_stream` now succeeds in ~1s on
every poll (`{'processed': 0, 'failed': 0}`) instead of erroring every time.

### Long-term Fix
None needed beyond the guardrail above — this is a one-line, correctly
-scoped fix; no broader redesign warranted.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — worth alerting on repeated Celery task
      failures for `consume_content_stream` specifically, since a silent
      failure loop here means system-generated notifications never reach
      students at all, with no user-facing error anywhere.
- [ ] Documentation to update — n/a
- [x] Code changes required — done (`NOTIFICATIONS/app/notifications/fanout.py`)

## Related Issues
- Found during the first staging deploy of the new `NOTIFICATIONS`
  microservice (HBEC-2026-09-14 notifications v1 build, same session).
- Separately during this same deploy: discovered that a plain
  `docker compose up -d --wait` against a *floating* `:latest` tag will not
  actually recreate a container whose image was rebuilt under the same tag
  — Compose compares config/tag, not image digest, so an already-running
  container silently keeps its old image. The real CD pipeline avoids this
  entirely by always using a unique `sha-<commit>` tag per deploy; a manual
  deploy using the floating `latest` tag needs an explicit
  `--force-recreate` (scoped to just the changed services) to actually
  apply a rebuilt image. Not filed as a separate entry — captured here since
  it was diagnosed in the same investigation and isn't itself a code bug,
  just an operational gotcha worth remembering for the next manual deploy.

## References
- `NOTIFICATIONS/app/notifications/fanout.py`
- `NOTIFICATIONS/tests/test_fanout.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery — diagnosed, fixed,
tested, and verified live on staging within the same deploy window.
