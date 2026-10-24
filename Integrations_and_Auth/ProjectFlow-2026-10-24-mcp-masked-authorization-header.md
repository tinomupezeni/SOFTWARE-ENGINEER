# ProjectFlow MCP Uses a Masked Authorization Header

**Date:** 2026-10-24
**Project:** ProjectFlow MCP
**Environment:** Development / installed local MCP
**Severity:** Medium
**Status:** Investigating

## Summary
The ProjectFlow MCP source assigns the returned access token but constructs the
`Authorization` header with the literal masked value `******`. Direct API
testing rejects that header, while the configured MCP task query nevertheless
returned data in the same runtime. The discrepancy remains unresolved and
should not be treated as proof that the header is valid.

## Symptoms
- The MCP executable starts successfully over stdio.
- Direct requests with no header or `Authorization: ******` return `401`;
  `Bearer <access_token>` returns `200`.
- Claude Code's MCP configuration supplies the ProjectFlow credentials through
  `/home/shadowe/.claude.json`; raw values were not printed.
- The configured `list_my_tasks(project_id=...)` query returned assigned HBCA
  tasks successfully.

## Environment Details
- **Server/Host:** Local development host `/home/shadowe`
- **Services Affected:** ProjectFlow MCP client; ProjectFlow API requests
- **Related Components:** `projectflow_mcp.server.get_auth`
- **Time First Observed:** 2026-10-24

## Investigation Steps

### 1. Initial Diagnosis
Located `/home/shadowe/Projects/projectflow-mcp`, confirmed its Python entry
point, README configuration, and installed pipx executable.

### 2. Root Cause Analysis
The login response stores `data.get("access_token")` in `token`, but the header
construction does not interpolate that variable:

```python
headers = {
    "Authorization": f"******",
    "Content-Type": "application/json"
}
```

The same implementation is present in the checked-in source used by the
editable installation.

### 3. Key Findings
- The MCP exposes `list_projects` and `list_my_tasks`, so the requested HBCA
  task query is supported.
- The server runs through stdio and is installed at
  `/home/shadowe/.local/bin/projectflow-mcp`.
- Claude Code registers it globally as a stdio server named `projectflow`,
  invoking `projectflow-mcp` with `PROJECTFLOW_EMAIL`,
  `PROJECTFLOW_PASSWORD`, and `PROJECTFLOW_API_URL`.
- The HBEC workspace `.mcp.json` does not define ProjectFlow; the global
  Claude Code configuration does.

## Root Cause
The source contains a masked authorization placeholder instead of the bearer
token returned by login. The reason the configured MCP query succeeded despite
this source state is unresolved.

## Prevention / Rule
**Guardrail:** Add an integration test that mocks the login response and asserts
that every API request carries `Authorization: Bearer <access_token>` using the
exact token returned by login, plus a negative request asserting masked and
missing headers are rejected by the API.

This catches placeholder headers and token-plumbing regressions without
requiring real credentials or exposing secrets.

## Solution

### Immediate Fix
No code was changed in this investigation. Live task retrieval was verified
through the configured MCP query, but the source/header discrepancy remains
open.

### Long-term Fix
Confirm why the configured MCP call succeeds despite the source showing a
masked header. Then restore the bearer-token header construction if the source
is authoritative, add the mocked authentication contract test, and keep
credentials supplied through the agent configuration environment.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None recorded.

## References
- `/home/shadowe/Projects/projectflow-mcp/src/projectflow_mcp/server.py:25-32`
- `/home/shadowe/.claude.json:/mcpServers/projectflow`

---

**Resolved By:** Unresolved
**Time to Resolution:** Ongoing
