# Paper-figure backfill failures are not traceable in production

**Date:** 2026-11-19
**Project:** HBEC
**Environment:** Production deployment path (PR #160)
**Severity:** High
**Status:** Investigating

## Summary

PR #160 introduces a deploy-triggered Celery backfill that uploads stored PDFs
to the Harness, but its new Admin task and HTTP-client error paths use the
legacy plain logger without the required JSON event schema, `trace_id`,
`span_id`, or `service.name`. Its new transport-exception path also logs the
exception as a string rather than with `.exception()` / stack fields. A failed
production backfill therefore cannot be correlated from deploy to Celery task
to Harness request, and loses the stack needed to diagnose transport failures.

## Symptoms

- `refresh_paper_figures` emits messages such as
  `refresh_paper_figures_failed paper=%s error=%s` without trace/span/service
  fields.
- `HarnessExtractionClient.refresh_figures_sync` catches `httpx.HTTPError` and
  records only its string representation.
- The deploy command intentionally continues after queueing failure, so these
  logs are the only production evidence that figure propagation did not begin.

## Environment Details

- **Server/Host:** Production blue/green cutover and singleton Admin worker
- **Services Affected:** Admin Backend Celery worker; Admin-to-Harness signed HTTP path
- **Related Components:** `seed_on_deploy`, `refresh_paper_figures`,
  `HarnessExtractionClient.refresh_figures_sync`
- **Time First Observed:** 2026-11-19 PR #160 review

## Investigation Steps

### 1. Initial Diagnosis

Reviewed the exact PR #160 head (`16028a0ed3042e6130733e4299d2e874e889cdb1`)
against the project telemetry rules and traced the cutover path in
`.github/workflows/cd.yml` to the Admin Celery task and Harness client.

### 2. Root Cause Analysis

```bash
git diff origin/experimental...origin/pr-160 -- ADMIN/adminBackend/apps/exam_papers/tasks.py ADMIN/adminBackend/apps/exam_papers/services/harness_client.py
git show origin/pr-160:.github/workflows/cd.yml
```

### 3. Key Findings

- The new task logs raw formatted strings and metadata blobs rather than JSON
  telemetry with the mandatory correlation fields.
- The new HTTP transport exception is caught with `logger.error(...)`, without
  `exc_info=True` or `.exception()`, so its stack is discarded.
- `seed_on_deploy` catches queueing failures to avoid blocking cutover; without
  structured correlated telemetry, operators cannot prove which papers were
  skipped or link the failure to the deploy and downstream Harness request.

## Root Cause

The feature was added to legacy Python logging paths without integrating the
repository's required JSON logging, W3C trace-context propagation, and
exception telemetry. The intended non-blocking deployment behavior magnifies
the observability gap because it deliberately preserves availability while
leaving the repair asynchronous.

## Prevention / Rule

**Guardrail:** Add a CI telemetry-contract check for all new Admin Celery tasks
and outbound HTTP clients that rejects log calls without `trace_id`, `span_id`,
and `service.name`, rejects caught exceptions not logged with stack metadata,
and exercises `traceparent` propagation on the client request.

This catches the exact paths that otherwise turn a non-blocking deploy failure
into an uncorrelated, low-information log line.

## Solution

### Immediate Fix

Do not merge PR #160 until its new task/client events use the configured JSON
logger, include the required correlation attributes, propagate W3C trace
context to Harness, and log caught transport exceptions with stack data.

### Long-term Fix

Standardize the Admin service's task and HTTP-client instrumentation so every
deployment-triggered background workflow exposes a traceable enqueue, retry,
terminal failure, and completion event with bounded paper identifiers.

## Prevention

- [ ] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues

- PR #160: Uploaded papers' figures reach students; figures embedded as images
  are found; production backfill on deploy

## References

- `/home/shadowe/Projects/HBEC/AGENTS.md` — mandatory telemetry rules
- `ADMIN/adminBackend/apps/exam_papers/tasks.py:1107-1169` at PR #160
- `ADMIN/adminBackend/apps/exam_papers/services/harness_client.py:606-630` at PR #160
- `.github/workflows/cd.yml:479-490` at PR #160

---

**Resolved By:** Codex
**Time to Resolution:** Review finding; implementation pending
