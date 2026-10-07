# FastAPI crash on feedback submission due to User model dependency mismatch

**Date:** 2026-10-03
**Project:** Club Zero
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The FastAPI backend crashed with a 500 error when a user attempted to submit feedback from the mobile app, causing a full container restart loop due to uncaught ASGI exceptions. The error originated from an incorrect assumption about the return type of the authentication dependency.

## Symptoms
- The mobile app reported "Error sending feedback".
- The API container logs showed `AttributeError: 'User' object has no attribute 'replace'`.
- The exception trace pointed to `uuid.UUID(current_user_id)` failing because it received a `User` object instead of a string.

## Environment Details
- **Server/Host:** local Docker (api container)
- **Services Affected:** `club-zero-backend-api-1`
- **Related Components:** `app/routers/feedback.py`, `app/dependencies.py`
- **Time First Observed:** 2026-10-03 17:11

## Investigation Steps

### 1. Initial Diagnosis
Checked the backend API logs using `docker compose logs --tail=50 api`.

### 2. Root Cause Analysis
The logs revealed the traceback:
```python
api-1  |   File "/app/app/routers/feedback.py", line 22, in submit_feedback
api-1  |     user_id=uuid.UUID(current_user_id),
api-1  |             ^^^^^^^^^^^^^^^^^^^^^^^^^^
api-1  |   File "/usr/local/lib/python3.12/uuid.py", line 175, in __init__
api-1  |     hex = hex.replace('urn:', '').replace('uuid:', '')
api-1  |           ^^^^^^^^^^^
api-1  | AttributeError: 'User' object has no attribute 'replace'
```
Reviewed `app/dependencies.py` and confirmed `get_current_user` returns a SQLAlchemy `User` instance, not a string UUID. 

### 3. Key Findings
- The route signature incorrectly typed the dependency as a string: `current_user_id: str = Depends(get_current_user)`.
- The code then tried to parse this `User` object into a `uuid.UUID` as if it were a string.

## Root Cause
A type mismatch between the expected dependency return type (string UUID) and the actual dependency return type (SQLAlchemy `User` object) was not caught by static analysis, leading to a runtime crash when the endpoint was exercised.

## Prevention / Rule
**Guardrail:** Enforce static type checking with `mypy` or `pyright` in the CI pipeline for all FastAPI router dependencies.

If `mypy` had been run, it would have flagged `current_user_id: str = Depends(get_current_user)` because the return type of `get_current_user` is explicitly annotated as `User`, preventing this runtime crash entirely.

## Solution

### Immediate Fix
Hot-patched the running container directly using `sed` to replace the incorrect variable name and access the `.id` property of the `User` object, then restarted the server.

```bash
docker exec club-zero-backend-api-1 sed -i 's/current_user_id: str = Depends(get_current_user)/current_user = Depends(get_current_user)/g' /app/app/routers/feedback.py
docker exec club-zero-backend-api-1 sed -i 's/user_id=uuid.UUID(current_user_id)/user_id=current_user.id/g' /app/app/routers/feedback.py
docker compose restart api
```

### Long-term Fix
Rebuilt the backend container from scratch with the corrected `app/routers/feedback.py` file to ensure the fix persists across deployments.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 5m
