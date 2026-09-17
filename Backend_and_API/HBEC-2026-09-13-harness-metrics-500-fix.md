---
title: Agentic Harness /metrics endpoint returning 500 Internal Server Error
date: 2026-09-13
author: Antigravity
status: Resolved
---

# Issue summary
The Agentic Harness `/metrics` endpoint in `health.py` was returning a 500 error because `_registry()` returns `None` if `PROMETHEUS_MULTIPROC_DIR` is not set in the environment. Calling `generate_latest(None)` fails with `AttributeError: 'NoneType' object has no attribute 'collect'`. This broke the Prometheus scrape completely, so no LLM usage metrics were being collected.

# Impact
Without LLM usage metrics, the Admin Backend's Model Settings page could not display total calls, errors, or success rates for the model adapters, making it impossible to detect models that were consistently erroring or inactive.

# Resolution
Updated `AGENTIC_HARNESS/app/api/routes/health.py` to gracefully fallback to the default registry if `PROMETHEUS_MULTIPROC_DIR` is not provided:
`generate_latest(_registry() or __import__("prometheus_client").REGISTRY)`.
Deployed this fix to the `harness` container on production, restoring the Prometheus scrapes.

Resolved By: Antigravity
