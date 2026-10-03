# Admin System Health Metrics Showing Zero

**Date:** 2026-09-23
**Project:** HBEC
**Environment:** Admin Backend
**Severity:** Minor (Observability)
**Status:** Found

## Summary
The "System Health" page in the Admin Frontend (previously part of System Settings) was reporting `0` for CPU Usage, Memory Usage, Uptime, Database Connections, and Cache Hit Rate. This is because the underlying endpoint `/settings/health/` (`SystemHealthView`) lacks the necessary library and implementation to fetch these real metrics.

## Root Cause
1. **Missing Dependency:** CPU and Memory usage are wrapped in a `try: import psutil` block, but `psutil` is not installed in the `adminBackend` environment. The `ImportError` is caught and passed silently, leaving the metrics at `0`.
2. **Hardcoded Zeros:** `dbConnections` and `cacheHitRate` are explicitly hardcoded to `0` in the response dictionary.
3. **Flawed Uptime Logic:** The `uptime` metric is calculated based on `SystemHealthView._start_time`, which is initialized to `time.time()` on the very first HTTP request to that specific view instance. This means the uptime resets to 0 seconds on the first visit or whenever the Gunicorn worker handling the request is cycled, rather than reflecting the actual host or service uptime.

## Next Steps
To fix this:
1. Add `psutil` to `requirements/base.txt` and install it.
2. Update `uptime` to use `psutil.boot_time()` or calculate it from the main process start time.
3. Implement actual queries for `dbConnections` (e.g., querying `pg_stat_activity` if PostgreSQL) and `cacheHitRate` (using Redis info stats), or remove them if not strictly necessary.

---
**Resolved By:** Antigravity CLI
