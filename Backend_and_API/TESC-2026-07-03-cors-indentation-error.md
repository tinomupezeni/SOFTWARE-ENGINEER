# CORS Blocked Requests Due to IndentationError Crash

**Date:** 2026-07-03
**Project:** TESC (ScalarEye)
**Environment:** Development (Docker Compose)
**Severity:** Critical
**Status:** Resolved

## Summary
The institution admin frontend (`http://localhost:8082`) was unable to communicate with the backend API (`http://localhost:8000`). All requests were blocked by the browser's CORS policy, and the backend returned 500 Internal Server Error for every endpoint.

## Symptoms
- Frontend console showed CORS errors: *"No 'Access-Control-Allow-Origin' header is present on the requested resource"*
- All API requests returned `net::ERR_FAILED 500 (Internal Server Error)`
- Endpoints affected included `POST /api/instauth/token/refresh/` and `GET /api/academic/institutions/`

## Environment Details
- **Server/Host:** localhost (Docker Compose)
- **Services Affected:** Backend (gunicorn on port 8000)
- **Related Components:** CORS middleware, URL routing, `academic/services/student_services.py`
- **Time First Observed:** 2026-07-03

## Investigation Steps

### 1. Initial Diagnosis
Checked `CORS_ALLOWED_ORIGINS` in `backend/core/settings.py` — `http://localhost:8082` was already present. The CORS config was correct.

### 2. Root Cause Analysis
Checked Docker container logs for the backend:
```bash
docker logs tesc-backend-1 --tail 50
```

Revealed a Python `IndentationError` during module import:
```
File "/app/academic/services/student_services.py", line 487
    categories=[info['category']],
IndentationError: unexpected indent
```

### 3. Key Findings
- The `IndentationError` occurred at import time, preventing Django from resolving URL patterns
- Since Django couldn't resolve URLs, every request returned 500
- The CORS middleware never completed its response cycle, so no `Access-Control-Allow-Origin` header was attached
- The CORS error in the browser was a *symptom* of the 500, not a misconfiguration

## Root Cause
In `backend/academic/services/student_services.py`, two extra keyword arguments (`categories` and `description`) were orphaned outside a `Program.objects.get_or_create()` call due to incorrect indentation. The `get_or_create()` was closed with `)` on line 486, but lines 487-489 still had dangling arguments with their own closing parenthesis.

```python
# Broken code (simplified):
program_obj, _ = Program.objects.get_or_create(
    ...
    defaults={...}
)
    categories=[info['category']],   # ← orphaned, wrong indent
    description="Auto-created via Student Upload"  # ← orphaned
)  # ← extra closing paren
```

## Prevention / Rule
**Guardrail:** Make `ruff check .` (or `python -m compileall`) a required, blocking CI step on every push — not a step developers are trusted to remember locally before committing.

An `IndentationError` is a syntax-level failure any linter or compile check catches instantly; the only reason it reached a running container is that nothing enforced the check between commit and deploy — a CI gate, not local discipline, closes that gap permanently.

## Solution

### Immediate Fix
Moved the orphaned `categories` and `description` fields into the `defaults` dict inside the `get_or_create()` call:

```python
# Fixed code:
program_obj, _ = Program.objects.get_or_create(
    ...
    defaults={
        ...
        "category": info['category'],
        "categories": [info['category']],
        "description": "Auto-created via Student Upload",
    }
)
```

Then rebuilt and restarted the backend container:
```bash
docker compose build backend && docker compose up -d backend
```

### Long-term Fix
No code changes needed beyond the fix. Prevent recurrence by running `python -m py_compile` on Python files before committing, or adding a lint step to CI.

## Prevention
- [ ] Add a CI lint step to catch syntax/indentation errors early
- [ ] Consider running `python -m compileall` in CI to catch import-time errors
- [x] Code changes applied

## Related Issues
- None

## References
- Docker logs (`docker logs tesc-backend-1`)

---

**Resolved By:** Tino
**Time to Resolution:** ~15 min
