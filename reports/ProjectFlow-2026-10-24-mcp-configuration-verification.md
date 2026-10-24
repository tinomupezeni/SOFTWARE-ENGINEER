# ProjectFlow MCP Configuration Verification

**Date:** 2026-10-24
**Project:** ProjectFlow MCP / HBEC
**Type:** Configuration Verification
**Status:** Completed

## Summary
Verified that Claude Code has a global ProjectFlow MCP registration with
credentials injected through environment variables and successfully queried
assigned HBCA tasks. The workspace-level HBEC MCP file does not register
ProjectFlow. A separate unresolved discrepancy remains between the MCP source's
masked authorization header and the successful configured query.

## Context / Trigger
The configured credentials were reported to already be available through Claude
Code, after an earlier inspection incorrectly concluded that the MCP could not
authenticate.

## Scope
Included Claude Code's global configuration, the HBEC workspace MCP file, the
installed ProjectFlow MCP entry point, the ProjectFlow MCP source, and a live
read-only ProjectFlow task query. No credentials were printed, changed, or
shared. No task mutations were performed.

## Method
Inspected configuration structure with secret values redacted, compared the
source and installed editable package, started the stdio entry point, tested
API authorization with missing, masked, and bearer headers, then queried the
HBCA project through the configured MCP environment.

## Decisions & Findings
- Claude Code's `/home/shadowe/.claude.json` registers a global stdio server
  named `projectflow` running `projectflow-mcp`.
- It supplies `PROJECTFLOW_EMAIL`, `PROJECTFLOW_PASSWORD`, and
  `PROJECTFLOW_API_URL` through the server environment.
- `/home/shadowe/Projects/HBEC/.mcp.json` defines Datadog and REA only; it does
  not define ProjectFlow.
- The server exposes `list_projects` and `list_my_tasks`.
- The HBCA project ID is `b58e9039-9c07-44ec-81af-ef0c4303cb8a`.
- Direct API checks returned `401` for missing and masked authorization and
  `200` for a real bearer token.
- The configured MCP query returned the assigned HBCA task list successfully,
  so the earlier claim that credentials were unavailable was incorrect.

## Changes Made
Updated the related issue record to reflect the verified configuration and the
remaining authorization-header discrepancy. No application or MCP source code
was changed.

## Verification
- ProjectFlow login: `200`.
- Project list through configured MCP: successful.
- HBCA assigned-task query through configured MCP: successful.
- Direct API authorization comparison: missing/masked `401`, bearer `200`.
- MCP stdio entry point: starts successfully.

## Follow-ups / Deferred
Investigate why the configured MCP call succeeds while the checked-in source
shows `Authorization: ******`. Do not remove or rotate the configured
credentials as part of this investigation.

## References
- `/home/shadowe/.claude.json`
- `/home/shadowe/Projects/HBEC/.mcp.json`
- `/home/shadowe/Projects/projectflow-mcp/src/projectflow_mcp/server.py`
- `Integrations_and_Auth/ProjectFlow-2026-10-24-mcp-masked-authorization-header.md`

---

**Completed By:** Copilot
**Duration:** 30 minutes
