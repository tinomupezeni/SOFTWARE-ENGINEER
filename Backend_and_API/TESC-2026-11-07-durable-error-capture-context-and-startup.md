# Durable error capture had startup and request-context edge cases

**Date:** 2026-11-07
**Project:** TESC
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The new database-backed backend error capture implementation initially failed during Django startup because the logging handler imported a model before the app registry was ready. After that was corrected, request-context state could leak between independently invoked error-recording paths, causing valid errors to be skipped or attributed to a previous request. Sensitive bearer authorization values were also only partially redacted.

## Symptoms
- Django could not initialize the configured database logging handler.
- Combined observability tests missed persisted request errors.
- A string such as `authorization=Bearer abc123` retained the bearer token after redaction.

## Environment Details
- **Server/Host:** Local development
- **Services Affected:** Django backend and Celery logging integration
- **Related Components:** `observability` app, Django logging configuration, request middleware
- **Time First Observed:** 2026-11-07

## Investigation Steps

### 1. Initial Diagnosis
Ran the observability test suite and Django management checks after adding the persistent error-event model, middleware, and logging handler.

### 2. Root Cause Analysis
```bash
python backend/manage.py test observability --verbosity 1
cd backend && USE_SQLITE=True python manage.py test observability --verbosity 1
```

### 3. Key Findings
- Logging configuration imports handlers before Django app models are ready.
- `ContextVar` error-deduplication state was not reset when a new request context was established.
- Direct error-recording paths could reuse stale request metadata.
- Authorization redaction matched only the first bearer token component.

## Root Cause
The observability implementation coupled logging-handler import-time loading to a top-level model import and treated request-scoped context state as if it were always entered through middleware. The redaction pattern did not model the optional `Bearer` prefix as part of the authorization value.

## Prevention / Rule
**Guardrail:** Keep Django model imports inside runtime recording functions used by logging configuration, and reset deduplication state whenever a request context is created; cover these paths with a SQLite-backed observability test suite.

This prevents app-registry startup failures and cross-request suppression while making the redaction contract executable.

## Solution

### Immediate Fix
- Deferred the `ErrorEvent` model import until `record_error()` executes.
- Reset error-deduplication state in `set_request_context()`.
- Used request-specific metadata when the active context belongs to another request.
- Redacted complete authorization values, including optional bearer prefixes.

### Long-term Fix
The durable error-event feature now includes startup, request middleware, logging-handler, handled-500, and redaction regression tests.

## Prevention
- [x] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None

## References
- `TESC/backend/observability/recording.py`
- `TESC/backend/observability/context.py`
- `TESC/backend/observability/tests.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
