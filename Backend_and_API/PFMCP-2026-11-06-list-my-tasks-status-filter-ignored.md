# ProjectFlow MCP: assigned-task status filter is ignored

**Date:** 2026-11-06
**Project:** ProjectFlow MCP (PFMCP)
**Environment:** Production
**Severity:** Low
**Status:** Investigating

## Summary
`list_my_tasks(status=...)` returns assigned tasks of every status, despite advertising a status filter.

## Symptoms
- A `status="TODO"` request includes `DONE` and `IN_PROGRESS` tasks.
- A `status="IN_PROGRESS"` request returns the same mixed list.

## Environment Details
- **Server/Host:** ProjectFlow production API
- **Services Affected:** `list_my_tasks` MCP tool
- **Related Components:** `src/projectflow_mcp/server.py` lines 74-105; `GET /api/tasks/`
- **Time First Observed:** 2026-11-06

## Investigation Steps

### 1. Initial Diagnosis
Called `list_my_tasks` with `TODO` and `IN_PROGRESS` status values. Both responses included all assigned statuses.

### 2. Root Cause Analysis
The MCP function passes `status` as a query parameter to `/tasks/`, then filters the returned list only by assignee. It does not apply a local status filter. The backend response appears to ignore this query parameter. The exact backend cause remains unverified.

```bash
rg -n -A 32 '^def list_my_tasks' src/projectflow_mcp/server.py
```

### 3. Key Findings
- The tool description promises optional status filtering.
- The client sends the query parameter but does not verify or enforce it.
- The two status-specific calls returned the same mixed list.

## Root Cause
The client relies on backend status filtering that is not present in the observed response and has no local fallback. Whether the backend does not implement this parameter or uses a different value format needs checking.

## Prevention / Rule
**Guardrail:** Add a contract test that calls `list_my_tasks(status="TODO")` against tasks with at least one `TODO` and one `DONE` assignment and asserts that only `TODO` entries are returned.

This catches silent backend query-filter drift while checking the MCP tool's user-visible promise.

## Solution

### Immediate Fix
None applied in this read-only task. Callers must filter the returned statuses themselves for now.

### Long-term Fix
Confirm the backend's supported status query contract and enforce the requested status in the MCP response even if the backend returns a mixed list.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- None known.

## References
- `src/projectflow_mcp/server.py:74-105`
- ProjectFlow MCP tool calls on 2026-11-06

---

**Resolved By:** Not yet resolved
**Time to Resolution:** Pending
