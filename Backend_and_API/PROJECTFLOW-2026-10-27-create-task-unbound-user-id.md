# create_task MCP tool crashes with UnboundLocalError if auth fails

**Date:** 2026-10-27
**Project:** ProjectFlow (projectflow-mcp)
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The `create_task` tool in the ProjectFlow MCP server (`src/projectflow_mcp/server.py`)
referenced a variable in its exception handler that was only guaranteed to
exist on the success path, masking the real error whenever authentication
failed.

## Symptoms
- If `get_auth()` raised (bad credentials, network error, non-200 from
  `/auth/login/`), the `except httpx.HTTPStatusError` branch tried to
  interpolate `user_id` into the error message.
- Since `user_id = user.get("id")` only runs after `get_auth()` returns
  successfully, this produced an `UnboundLocalError` instead of the intended
  "Error creating task" message, hiding the actual auth failure from the
  caller.

## Environment Details
- **Server/Host:** N/A (local MCP server, stdio transport)
- **Services Affected:** `create_task` tool
- **Related Components:** `get_auth()`, ProjectFlow REST API (`/auth/login/`, `/tasks/`)
- **Time First Observed:** Found during a code read-through, not a live incident.

## Investigation Steps

### 1. Initial Diagnosis
Reading `create_task` while reviewing the MCP server for a feature-expansion
pass. The `except httpx.HTTPStatusError` handler used `user_id` in its
f-string.

### 2. Root Cause Analysis
Traced `user_id`'s assignment: it's set from the tuple returned by
`get_auth()`, which is called inside the `try` block. If `get_auth()` itself
raises before returning, `user_id` is never assigned, so any exception
handler referencing it fails with its own `UnboundLocalError` when triggered
by an auth failure specifically.

### 3. Key Findings
- Only the `httpx.HTTPStatusError` branch referenced `user_id`; the generic
  `except Exception` branch did not, so most failures still reported
  correctly — only the narrower HTTPStatusError-during-auth-failure path
  (not actually reachable here) and any future handler reuse were at risk.
- No test coverage exists for this module.

## Root Cause
Exception handler assumed a local variable from the `try` block's
success path was always bound, without accounting for the exception
originating before that variable's assignment.

## Prevention / Rule
**Guardrail:** Never reference a variable assigned inside a `try` block from
that block's `except` clauses unless the variable is initialized (e.g. to
`None`) before the `try` starts. A lint rule (`flake8-bugbear`'s
use-after-try patterns, or a simple code-review checklist item) catches this
class of bug before merge.

This closes the gap because it removes the implicit assumption that
exception handlers only run after certain lines of the `try` block have
executed.

## Solution

### Immediate Fix
Removed the `user_id` reference from the `except httpx.HTTPStatusError`
message in `create_task`, matching the pattern already used by the other
tools in the file.

```python
except httpx.HTTPStatusError as e:
    return f"Error creating task: {e.response.status_code} - {e.response.text}"
```

### Long-term Fix
No further action needed for this specific instance; noted as a
code-review checklist item for future tools added to this server.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done)

## Related Issues
- None

## References
- `src/projectflow_mcp/server.py` (projectflow-mcp repo)

---

**Resolved By:** tinomupezeni
**Time to Resolution:** < 15 minutes
