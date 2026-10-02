# Order/cart telemetry silently failed on every single call since it was written

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Production
**Severity:** Low
**Status:** Resolved

## Summary
`TelemetryService.track_event` (fired via `BackgroundTasks` on every
`cart_add`, `order_created`, and `order_status_updated` event) made an
HTTP POST to `settings.BRAIN_API_URL/ingest` - a hostname
(`tese-brain-api:8000`) that hasn't existed since Brain was consolidated
into this same app. The call was wrapped in a try/except that only
printed a log line, so it failed silently on every single invocation,
with no order-analytics event ever actually recorded.

## Symptoms
- Not reported by a user - found while auditing the codebase for
  leftover microservice-era code (see the companion architecture entry
  for `app/main.py`).
- Consequence: the `events` table / Brain analytics module has never
  received a single order or cart event from the live app, despite the
  code clearly being written with that intent and wired into every order
  mutation.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-store-api`
  container)
- **Services Affected:** Order/cart analytics (Brain module's event
  stream); no user-facing impact since the call is fire-and-forget via
  `BackgroundTasks`, after the response is already sent
- **Related Components:**
  `apps/store-api/app/modules/orders/services/telemetry_service.py`,
  `apps/store-api/app/modules/brain/routes/intelligence.py`
- **Time First Observed:** 2026-10-02

## Investigation Steps

### 1. Initial Diagnosis
Grepped for every remaining reference to the legacy `*_API_URL` settings
while cleaning up `main.py` and found `telemetry_service.py` was the one
real, live-invoked caller (unlike `composite.py`, which had zero
callers).

### 2. Root Cause Analysis
Confirmed `BRAIN_API_URL` defaults to `http://tese-brain-api:8000` and is
not overridden by any env var in production (`docker exec tese-store-api
env | grep BRAIN_API_URL` returned nothing). Confirmed the call site in
`orders/routes/order.py` dispatches via
`background_tasks.add_task(TelemetryService.track_event, ...)` - so the
failure never affected checkout/cart response times or success, only
silently dropped every event.

### 3. Key Findings
- The actual event-ingestion logic (`push_event_to_stream` /
  `flush_events_to_db`, in `app/modules/brain/routes/intelligence.py`)
  already lives in-process in this same app - the HTTP call was never
  necessary even under the old architecture's assumptions, since Brain's
  `/ingest` route itself just does a local Redis `xadd`.
- Fixing this only required making `telemetry_service.py` call that
  existing in-process logic directly instead of over HTTP - no new
  functionality needed, just removing a pointless network hop that
  happened to point at a dead host.

## Root Cause
Same root cause as the `main.py` orchestrator cleanup: a telemetry client
written to talk to "the Brain microservice" over HTTP, never updated
after Brain was consolidated into the same process.

## Prevention / Rule
**Guardrail:** Any inter-module call in this app should go through a
plain Python function/import, never HTTP to `settings.*_API_URL` - those
settings no longer correspond to anything reachable. (All such settings
were removed as part of the companion `main.py` cleanup, so this
specific guardrail is now also structurally enforced: there's nothing
left to accidentally call.)

## Solution

### Immediate Fix
- `app/modules/brain/routes/intelligence.py`: extracted
  `push_event_to_stream(event: EventIn) -> None` as a plain function,
  used by both the `/ingest` route and (now) `TelemetryService` directly.
- `app/modules/orders/services/telemetry_service.py`: rewritten to
  `import` and call `push_event_to_stream` + `flush_events_to_db`
  in-process instead of `httpx.post`-ing to `BRAIN_API_URL`. Same
  call signature (`track_event(event_name, user_id=, properties=)`), so
  no changes needed at any of the 3 call sites in `order.py`.

```bash
python3 -m py_compile app/modules/brain/routes/intelligence.py \
  app/modules/orders/services/telemetry_service.py   # clean
```
Verified end-to-end in production: registered a test account, added an
item to cart, confirmed no `[Telemetry] Failed` line in
`docker logs tese-store-api`, and confirmed a real `cart_add` row landed
in the `events` table (`SELECT event_name, user_id, timestamp FROM
events ORDER BY timestamp DESC LIMIT 3` - first successful telemetry
event ever recorded via this path).

### Long-term Fix
None needed - this was a dead-endpoint bug, now a working in-process call.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `Architecture_and_Design/tese-marketplace-2026-10-02-dead-smart-orchestrator-proxy-layer.md`
  (same root cause, different file)
- `reports/tese-marketplace-2026-10-02-foundations-alembic-and-dead-code-cleanup.md`

## References
- `apps/store-api/app/modules/orders/services/telemetry_service.py`
- `apps/store-api/app/modules/brain/routes/intelligence.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~15 minutes from discovery to verified fix in production
