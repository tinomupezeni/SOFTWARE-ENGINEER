# Admin Ingestion Review "Save Mapping" Calls a Route That Doesn't Exist

**Date:** 2026-09-22
**Project:** HBEC
**Environment:** Discovered during a dead-code audit of admin backend/frontend
(cross-referencing every frontend API call against the backend's actual
routes)
**Severity:** Medium — a real admin-facing action is broken with no visible
error path confirmed yet
**Status:** Investigating (found, not yet fixed — logged per the
found-or-fixed rule; fix is follow-up work, not part of this session's scope)

## Summary
While auditing for dead backend endpoints, the reverse case turned up:
`ADMIN/adminFrontend/src/features/ingestion/api/ingestionApi.ts:277` calls
`PATCH /ingestion/review-queue/${id}/mapping/`. `apps/ingestion/urls.py`
defines only `review-queue/<uuid:pk>/`, `/approve/`, `/reject/` for
`ReviewQueueItemView` — no `/mapping/` route exists anywhere in the backend.

## Symptoms
Not yet reproduced against a live UI action — found by static cross-reference
of frontend calls against backend routes, not from a user report. Expected
symptom: saving a mapping in the ingestion review queue UI either silently
no-ops or surfaces a 404, depending on how the calling code handles the
response.

## Investigation Steps

### 1. Initial Diagnosis
Built a full list of every backend route (`ADMIN/adminBackend/apps/*/urls.py`)
and every frontend API call site (`ADMIN/adminFrontend/src/features/*/api/`),
cross-referenced both directions. This asymmetry — a frontend call with no
matching backend route — was the only one found in the reverse direction.

### 2. Root Cause Analysis
`apps/ingestion/urls.py` routes for `ReviewQueueItemView`:
```python
path("review-queue/<uuid:pk>/", ...)
path("review-queue/<uuid:pk>/approve/", ...)
path("review-queue/<uuid:pk>/reject/", ...)
```
No `mapping/` suffix. The frontend's `saveMapping`-shaped call at
`ingestionApi.ts:277` has no backend counterpart at all — not a typo'd path
near a real one, a route that was apparently never built.

### 3. Key Findings
- Not yet determined whether this is a frontend call that was written ahead
  of a backend endpoint that was never finished, or a renamed/removed
  backend route with the frontend left stale.

## Root Cause
Undetermined pending further investigation — flagged here so it isn't lost,
not yet root-caused to a specific commit or design decision.

## Prevention / Rule
**Guardrail:** none proposed yet — this needs its own investigation before a
guardrail can be named (e.g. a CI check that diffs frontend `apiFetch` call
paths against backend `urlpatterns`, which is exactly the manual process that
found this).

## Solution

### Immediate Fix
None yet — out of scope for the dead-code cleanup session that surfaced this.
Logged so it's tracked rather than silently noted and forgotten.

### Long-term Fix
Needs: (1) decide whether "save mapping" should exist as a distinct action
from a plain `PATCH` on the review-queue item, (2) either build the missing
`/mapping/` endpoint or point the frontend at the correct existing route,
(3) add a test exercising the actual UI action.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — this entry
- [ ] Code changes required — pending

## Related Issues
Surfaced by `Architecture_and_Design/HBEC-2026-09-22-dead-code-audit-admin-backend-frontend.md`.

## References
- `ADMIN/adminFrontend/src/features/ingestion/api/ingestionApi.ts:277`
- `ADMIN/adminBackend/apps/ingestion/urls.py`
- `ADMIN/adminBackend/apps/ingestion/views.py` (`ReviewQueueItemView`)

---

**Resolved By:** Not yet resolved
**Time to Resolution:** N/A
