# Harness `/metrics` 500s on Production — `PROMETHEUS_MULTIPROC_DIR` Unset, and `_registry()` Doesn't Actually Fall Back to `None` Safely

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Identified, not fixed (unrelated to today's promotion, pre-existing)

## Summary
Found while watching harness logs during today's production promotion
(unrelated to the deployed changes — confirmed staging shows none of this).
Every scrape of `/metrics` on production's harness throws:

```
File "/app/app/api/routes/health.py", line 93, in metrics
    content=generate_latest(_registry()),
AttributeError: 'NoneType' object has no attribute 'collect'
```

## Root Cause
`app/api/routes/health.py::_registry()`:

```python
if not os.environ.get("PROMETHEUS_MULTIPROC_DIR"):
    return None
...
```

Its own docstring claims: *"Unset, this returns None and `generate_latest`
behaves exactly as it did [before multiprocess mode was added]."* That's
incorrect — `prometheus_client.generate_latest(registry)` calls
`registry.collect()` unconditionally on whatever is passed; it does not
treat `None` as "use the default global `REGISTRY`" the way calling
`generate_latest()` with **no argument** would. Passing `None` explicitly
crashes exactly as observed.

Production's environment does not set `PROMETHEUS_MULTIPROC_DIR` (staging's
does, or staging's request pattern doesn't hit this path — the error does
not appear in staging's logs at all). So every `/metrics` scrape against
production 500s.

## Symptoms
No functional impact confirmed — this is scoped to the `/metrics` route
handler only, caught by Starlette's error middleware per-request; `/health`
and real API traffic are unaffected (verified directly:
`docker exec hbec-harness curl -sf http://localhost:8080/health` → `200
{"status":"ok",...}` while this was actively occurring). The practical
effect is Prometheus has been unable to scrape harness metrics on
production — dashboards and alerts backed by harness metrics have likely
been silently empty.

## Solution

### Immediate Fix
None applied — out of scope for today's promotion, and not caused by it
(`health.py` was untouched by any change deployed today). Flagged for a
dedicated fix.

### Long-term Fix
Two independent things need fixing:
1. `_registry()`'s fallback is wrong — either fix the docstring's premise
   (it does not "behave exactly as it did") or fix the call site:
   `generate_latest(_registry() or None)` — no, correctly:
   `content=generate_latest(_registry()) if _registry() else generate_latest()`,
   or simplest, use the sentinel differently: `reg = _registry(); content =
   generate_latest(reg) if reg is not None else generate_latest()`, i.e. call
   `generate_latest()` with **zero arguments** when there's no multiprocess
   registry, so it reads the default global `REGISTRY` as intended.
2. Decide whether production is *supposed* to run with
   `PROMETHEUS_MULTIPROC_DIR` set (matching however many uvicorn workers it
   runs, per `_registry()`'s own docstring rationale about the harness's 4
   workers each holding a separate registry) — if so, that's a real env-var
   gap in `docker-compose.production.yml`/`.env`, separate from the code fix
   above and probably the more important one, since without it metrics are
   scoped to whichever single worker answered a scrape rather than
   aggregated correctly.

## Prevention
- [ ] Monitoring/alerts to add — an alert on `/metrics` scrape failures
      would have caught this without needing someone to read raw container
      logs
- [ ] Documentation to update — n/a
- [ ] Code changes required — the two items above, not done in this
      session (out of scope for the promotion in progress)

## Related Issues
- Found during the same production promotion as
  `2026-09-11-production-had-26-unmerged-duplicate-subjects-blocking-subjectfamily-migration.md`,
  unrelated cause.

## References
- `AGENTIC_HARNESS/app/api/routes/health.py::metrics`, `::_registry`

---

**Resolved By:** Not yet — identified only, flagged for a dedicated fix
**Time to Resolution:** N/A
