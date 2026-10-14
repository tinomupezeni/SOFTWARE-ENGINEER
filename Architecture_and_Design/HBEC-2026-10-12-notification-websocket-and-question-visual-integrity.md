# Notification WebSocket and Question Visual Integrity Hardening

**Date:** 2026-10-12
**Project:** HBEC
**Area:** Architecture_and_Design / Reliability

## Findings

Notification delivery uses a browser WebSocket backed by a per-worker Redis
Pub/Sub listener. The canonical production nginx templates already forwarded
WebSocket upgrades, but the checked-in staging student nginx configuration did
not route notification REST or WebSocket traffic at all. This could turn a
healthy notification service into an apparent client-side reconnect failure.

The direct Harness-paper frontend path also dropped the optional `diagram`
field while mapping Harness questions into the student domain model. Valid
code-drawn figures therefore disappeared before `QuestionDisplay` could render
them. Questions flagged by the Harness as promising an unavailable visual also
needed to retain that honest warning.

## Resolution

1. Added staging REST and WebSocket proxy locations with HTTP/1.1 upgrade
   forwarding and a long WebSocket read timeout.
2. Added Prometheus/OpenMetrics instrumentation to the Notifications service
   for active connections, lifecycle/send failures, Redis listener state,
   reconnects, malformed messages, and received pushes.
3. Added a `/metrics` endpoint and declared `prometheus-client` as a service
   dependency. The deployment monitoring scrape target still needs to follow
   the active blue/green notification service rather than an inactive color.
4. Preserved and validated Harness-provided diagrams in the direct frontend
   mapper, and added regression coverage for both valid diagrams and honest
   missing-visual warnings.
5. Kept the existing REST/polling path as the correctness fallback; WebSocket
   messages remain lightweight invalidation signals rather than data authority.

## Validation

- Notifications Ruff and Python compilation: passed.
- Prometheus exposition smoke test: passed.
- Student diagram and WebSocket tests: 33 passed.
- Student frontend build-mode typecheck: passed.
- Staging nginx syntax validation in `nginx:1.27-alpine`: passed.
- Full Notifications WebSocket tests remain blocked locally because the
  configured PostgreSQL test instance at `127.0.0.1:5545` is not running.

Resolved By: Copilot
