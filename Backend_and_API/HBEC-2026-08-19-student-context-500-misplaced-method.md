# Every Harness Student-Context Call 500'd — Method Defined Under the Wrong Class

**Date:** 2026-08-19
**Project:** HBEC
**Environment:** Staging and Production
**Severity:** High
**Status:** Resolved

## Summary
A routine post-deploy log sweep across every staging container found `GET /api/internal/student-context/{user_id}/` 500ing on every single call, with `AttributeError: 'StudentContextView' object has no attribute '_build_context'`. This is the endpoint the Agentic Harness uses to build a student's active session/project/profile context for Friday, exam practice, and every other pillar — it had been failing silently (degrading gracefully, not crashing the student-facing feature) for an unknown period before being noticed.

## Symptoms
- Structured JSON error log: `"message": "Internal Server Error: /api/internal/student-context/...", "error.type": "AttributeError", "error.message": "'StudentContextView' object has no attribute '_build_context'"`
- Harness-side logs showed `context_profile_failed` immediately after, then `context_assembled` with a reduced section count — the harness's own per-source-degrades-independently design meant nothing crashed for the student, it just silently lost the student-profile/session/project context section on every request

## Environment Details
- **Server/Host:** VPS (staging, then confirmed same bug present on production before it was promoted)
- **Services Affected:** `hbec-student-backend`
- **Related Components:** `STUDENT/hbec_backend/apps/internal/views.py` — `StudentContextView`, `SyncStudentView`
- **Time First Observed:** 2026-08-19, during a routine post-deploy error-log sweep across all 29 staging containers

## Investigation Steps

### 1. Initial Diagnosis
```bash
docker logs hbec-student-backend --since 24h | grep -iE "error|exception|traceback"
```
Found the `AttributeError` immediately — this wasn't subtle, but nobody had been looking at these specific internal-endpoint logs before.

### 2. Root Cause Analysis
Read `apps/internal/views.py` directly: `StudentContextView.get()` (line ~100) calls `self._build_context(user_id, session_id)`, but the actual `_build_context` method (a ~120-line method building session/project/activity/friction-signal data) was defined at the same indentation level as, and physically located inside, the **next class down** — `SyncStudentView` — not `StudentContextView`. A clean misplaced-method bug, almost certainly from a bad merge.

### 3. Key Findings
- The method itself was completely correct and complete — it just belonged to the wrong class, a pure structural/indentation bug rather than a logic bug
- `SyncStudentView` (the class that accidentally owned it) never actually called `_build_context` at all, so the method sat there silently unused from that class's perspective

## Root Cause
`_build_context`'s definition was nested under `class SyncStudentView(APIView):` instead of `class StudentContextView(InternalAuthMixin, APIView):`, so any call to it from `StudentContextView.get()` raised `AttributeError`.

## Prevention / Rule
**Guardrail:** A CI test that directly calls every internal endpoint's handler (`StudentContextView().get(...)`, not just an HTTP-level smoke test) against a real object, so a `self.<method>` reference with no matching definition in its own class fails immediately.

Python doesn't check method membership until the line actually executes — a bad merge silently misplaced this method and nothing exercised the endpoint until real traffic hit it in production, for an unknown period, degrading gracefully instead of loudly.

## Solution

### Immediate Fix
Moved the entire `_build_context` method body into `StudentContextView`, immediately after its `get()` method, and removed the duplicate copy from under `SyncStudentView`.

```python
class StudentContextView(InternalAuthMixin, APIView):
    def get(self, request, user_id): ...
    def _build_context(self, user_id, session_id): ...  # moved here

class SyncStudentView(APIView):
    def post(self, request): ...  # _build_context removed from here
```

### Long-term Fix
Committed as `86f3882` (`fix(student): move misplaced _build_context method to StudentContextView`). Verified with `pytest apps/internal/` (13/13 passed) and `ruff check`/`ruff format --check`, then verified live against the real endpoint post-deploy on both staging and production with a hand-crafted HMAC-signed request — confirmed the endpoint returns a full `student_profile`/`active_session`/`recent_activity` payload instead of 500ing.

## Prevention
- [x] Code changes required (committed)
- [ ] A structural lint/CI check that flags a method reference (`self._method_name`) with no matching definition anywhere in the same class — would have caught this at merge time instead of silently degrading in production

## References
- `STUDENT/hbec_backend/apps/internal/views.py`

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~20 minutes
