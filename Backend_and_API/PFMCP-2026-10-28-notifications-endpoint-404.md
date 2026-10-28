# ProjectFlow MCP: list_notifications 404s against backend

**Date:** 2026-10-28
**Project:** ProjectFlow MCP (PFMCP)
**Environment:** Production (`https://projectflow.thuthuka.tech/api`)
**Severity:** Medium
**Status:** Investigating (root cause confirmed, fix is cross-repo)

## Summary
`list_notifications` (and by extension `mark_notification_read` /
`mark_all_notifications_read`) in the ProjectFlow MCP server call
`GET /api/notifications/` on the ProjectFlow backend. The backend returns a
genuine `404 Not Found` — not an auth error — meaning the route itself does
not exist server-side.

## Symptoms
- `mcp__projectflow__list_notifications` returns:
  `Error listing notifications: Client error '404 Not Found' for url
  'https://projectflow.thuthuka.tech/api/notifications/'`
- No stack trace surfaced to the user beyond the httpx exception text.

## Environment Details
- **Server/Host:** projectflow.thuthuka.tech (Django/DRF backend, separate
  repo from `projectflow-mcp`)
- **Services Affected:** `list_notifications`, `mark_notification_read`,
  `mark_all_notifications_read` tools in `projectflow-mcp`
- **Related Components:** `src/projectflow_mcp/server.py` lines 435-482
- **Time First Observed:** 2026-10-28, during a routine "check my tasks and
  messages" session

## Investigation Steps

### 1. Initial Diagnosis
Ran `list_notifications` via the MCP tool; got a 404 from an authenticated
request. Compared against other tools added in the same commit
(`list_milestones`, `list_time_entries`) — both returned clean empty
results ("No milestones found." / "No time entries found."), ruling out a
blanket auth/connectivity problem.

### 2. Root Cause Analysis
Confirmed via unauthenticated probes against the live backend:
- `GET /api/tasks/` → `401 Unauthorized` (route exists, requires auth — expected)
- `GET /api/notifications/` → `404 Not Found` (route does not exist at all,
  even without auth)

Also checked the DRF API root (`GET /api/`), which only lists `workspaces`
as a registered top-level route — not authoritative for what else exists,
but consistent with a backend that was never extended with a notifications
app/router.

### 3. Key Findings
- The notifications tools (along with chat/comments, search, milestones,
  time tracking, and project-member tools) were all added in a single
  commit (`f4f30c0`) without a corresponding check against the live backend.
- `list_milestones` and `list_time_entries`, added in the same commit, do
  work — so this isn't a wholesale untested-batch problem, just this one
  endpoint family.
- `/api/notifications/`, `/api/notifications/{id}/`, and
  `/api/notifications/mark-all-read/` are all referenced by the client but
  none exist on the backend.

## Root Cause
The ProjectFlow MCP client (`projectflow-mcp`) was written against an
assumed API contract for notifications that the ProjectFlow backend never
implemented. This is a cross-repo contract gap, not a bug in request
construction — the client is calling the URL correctly, the resource just
isn't there.

## Prevention / Rule
**Guardrail:** Before adding an MCP tool that calls a new backend endpoint,
require one live smoke call (even an unauthenticated probe for route
existence, as done here) against the real backend and record the resulting
status code in the PR/commit description. A 401 confirms the route exists;
a 404 means the contract doesn't hold yet and the tool must not be merged
as if it were ready.

This closes the gap because the failure mode here (shipping a client tool
for an endpoint nobody built) is only catchable by actually hitting the
backend once — it can't be caught by reading the client code in isolation.

## Solution

### Immediate Fix
None yet — this requires either implementing `/api/notifications/` on the
ProjectFlow backend (separate repo), or, as a client-side stopgap, making
`list_notifications`/`mark_notification_read`/`mark_all_notifications_read`
fail with a clear "not supported by backend yet" message instead of a raw
httpx exception string.

### Long-term Fix
Implement the notifications REST resource on the ProjectFlow backend:
- `GET /api/notifications/` (list, with `is_read` filter support)
- `PATCH /api/notifications/{id}/` (mark one read)
- `POST /api/notifications/mark-all-read/`

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (backend: implement endpoint; client:
      friendlier error message as an interim measure)

## Related Issues
- None yet — first PFMCP entry in this repo.

## References
- `src/projectflow_mcp/server.py:435-482` (projectflow-mcp)
- Commit `f4f30c0` ("Fix UnboundLocalError in create_task; add
  chat/comments, notifications, search, milestones, time tracking, and
  project-member tools")

---

**Resolved By:** Tinotenda Mupezeni (via Claude Code)
**Time to Resolution:** Root cause confirmed same session; backend fix
pending (cross-repo, not owned by `projectflow-mcp`).
