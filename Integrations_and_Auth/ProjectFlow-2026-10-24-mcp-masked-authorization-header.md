# ProjectFlow MCP Uses a Masked Authorization Header

**Date:** 2026-10-24
**Project:** ProjectFlow MCP
**Environment:** Development / installed local MCP
**Severity:** High
**Status:** Investigating

## Summary
The ProjectFlow MCP authenticates successfully in `get_auth()` but discards the
returned access token and sends the literal masked value `******` as the
`Authorization` header for every subsequent API request. The installed server
therefore cannot authenticate project, task, notification, or comment requests.

## Symptoms
- The MCP executable starts successfully over stdio.
- Authenticated API calls made by its tools would use `Authorization: ******`.
- The current agent session has no `PROJECTFLOW_EMAIL` or
  `PROJECTFLOW_PASSWORD` environment variables, so live task retrieval could
  not be completed either.

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

The same implementation is present in the installed package and the checked-in
source.

### 3. Key Findings
- The MCP exposes `list_projects` and `list_my_tasks`, so the requested HBEC
  task query is conceptually supported.
- The server runs through stdio and is installed at
  `/home/shadowe/.local/bin/projectflow-mcp`.
- No ProjectFlow MCP server registration was found in the inspected Claude,
  Gemini, or Copilot configuration files.
- No ProjectFlow credentials were present in the current process environment.

## Root Cause
The authorization header was replaced with a masked placeholder while the
access token assignment remained in place, making all authenticated API calls
unauthorized.

## Prevention / Rule
**Guardrail:** Add an integration test that mocks the login response and asserts
that every API request carries `Authorization: Bearer <access_token>` using the
exact token returned by login.

This catches placeholder headers and token-plumbing regressions without
requiring real credentials or exposing secrets.

## Solution

### Immediate Fix
No code was changed in this investigation. Live task retrieval was not claimed
because credentials were unavailable and the MCP authorization implementation
is defective.

### Long-term Fix
Restore the bearer-token header construction, add the mocked authentication
contract test, rebuild/reinstall the package, and register the MCP with
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
- `/home/shadowe/Projects/projectflow-mcp/README.md:13-36`

---

**Resolved By:** Unresolved
**Time to Resolution:** Ongoing
