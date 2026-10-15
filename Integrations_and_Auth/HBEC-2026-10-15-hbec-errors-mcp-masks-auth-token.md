# HBEC Errors MCP Masks Its Authentication Token

**Date:** 2026-10-15
**Project:** HBEC
**Environment:** Production diagnostics tooling
**Severity:** High
**Status:** Resolved

## Summary
The registered `hbec-errors` MCP server successfully logs in to Admin Backend
but replaces the returned access token with the literal string `******` before
using it for subsequent API requests. Every MCP tool call therefore receives
an unauthorized response instead of the requested production error data.

## Symptoms
- The MCP command could authenticate but could not list production errors.
- The tool's `get_auth()` returned `Authorization: ******`.
- Direct REST access using the same configured credentials succeeded.

## Environment Details
- **Server/Host:** `/home/shadowe/Projects/hbec-errors-mcp`
- **Services Affected:** HBEC errors MCP diagnostics tool
- **Related Components:** Admin Backend authentication and system-error API
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the registered MCP configuration and invoked the configured
diagnostics path against the Admin Backend API.

### 2. Root Cause Analysis
The login response's `accessToken` is assigned to `token`, but the returned
headers interpolate a masking placeholder instead of that token.

```python
token = response.json().get("accessToken")
return {"Authorization": f"******", "Content-Type": "application/json"}
```

### 3. Key Findings
- Admin Backend login returns HTTP 200.
- The same credentials can retrieve system errors when the real bearer token
  is used.
- The defect affects all five MCP tools because each calls `get_auth()`.

## Root Cause
The authentication header was left redacted in executable code rather than
only in displayed/logged output, so the MCP server never sends the bearer
token it obtained.

## Prevention / Rule
**Guardrail:** Add an MCP integration test that mocks login and asserts every
authenticated request carries `Authorization: Bearer <accessToken>` while
asserting the token is absent from returned diagnostic text and logs.

This catches accidental credential masking in the request path while
preserving the separate requirement not to expose secrets in tool output.

## Solution

### Immediate Fix
Used the configured Admin Backend credentials with a direct, non-persistent
REST request to retrieve the current production errors and technical feedback.
No credentials or tokens were written to the repository. This workaround was
removed after correcting the MCP implementation.

### Long-term Fix
Changed the MCP implementation to return the actual bearer token in the
request headers, added authentication regression tests, and reinstalled the
local executable in editable mode. A live authenticated system-error read
then succeeded against Admin Backend.

## Prevention
- [x] Correct the Authorization header in `hbec-errors-mcp`
- [x] Add the authentication regression test
- [x] Reinstall/restart the registered MCP executable
- [x] Verify authenticated system-error access after the fix

## Related Issues
- None.

## References
- `/home/shadowe/Projects/hbec-errors-mcp/src/hbec_errors_mcp/server.py:29-30`
- HBEC Admin Backend `/api/auth/login/`
- HBEC Admin Backend `/api/settings/system-errors/`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
