# Agentic Harness HTTP 500 on Paper Replication (UnboundLocalError: uuid)

**Date:** 2026-09-30
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved (confirmed 2026-10-05)

## Summary
The Agentic Harness (FastAPI) was returning HTTP 500 Internal Server Error when the Admin Backend attempted to replicate `paper.published` events. This caused bulk syncs and individual paper publishes to fail when communicating with the AI Harness, leaving the Harness without the latest paper data.

## Symptoms
- Admin backend replication dashboard showed repeated failures for `paper.published` events to the `harness` target, with the error `HTTP 500: Internal Server Error`.
- The `hbec-harness` docker container logs showed a traceback ending in `UnboundLocalError: cannot access local variable 'uuid' where it is not associated with a value`.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** `hbec-harness` (Agentic Harness), `hbec-admin-worker`
- **Related Components:** Admin Backend Replication Tasks (`replicate_paper_to_harness`), Harness FastAPI handlers.
- **Time First Observed:** 2026-09-30

## Investigation Steps

### 1. Initial Diagnosis
Checked the replication dashboard and saw `paper.published` failing with 500 errors to the `harness` target. SSH'd into the deployment VPS (`hbca-vps`) and inspected the `hbec-harness` docker container logs to retrieve the exact traceback.

### 2. Root Cause Analysis
The traceback pointed to line 520 in `AGENTIC_HARNESS/app/admin/replication_handlers.py` within the `handle_paper_replication` function.
Reviewed the source code for `handle_paper_replication`:
- At line 460, an `import uuid` statement is nested inside an `if event_type == "paper.archived":` block.
- For `paper.published` events, this block is skipped, leaving the `uuid` module unimported in the local scope.
- At line 520, the code attempts to create a new Paper record with `id=uuid.uuid4()`.
- Because `uuid` was never imported for this event type, Python raises an `UnboundLocalError`.

### 3. Key Findings
- The `uuid` import was incorrectly scoped inside a conditional block meant only for archiving events.
- The student backend sync is unaffected by this specific bug as it uses Redis streams, but the harness relies on these HTTP webhook payloads.

## Root Cause
A Python scoping bug: the `uuid` module was imported locally inside an `if` block that only executes for `"paper.archived"` events. When a `"paper.published"` event arrives, the `if` block is skipped, leaving the `uuid` variable unbound when `uuid.uuid4()` is subsequently called to generate a primary key for the new paper.

## Prevention / Rule
**Guardrail:** Enable strict Python linting (e.g. `ruff` or `flake8` with `F821` undefined name checks) across the `AGENTIC_HARNESS` codebase, and configure it to fail the CI build on unresolved references.

Moving module-level imports to the top of the file (PEP 8 standard) or enforcing a linter that catches uninitialized variables would proactively prevent this specific class of runtime `UnboundLocalError`.

## Solution

### Immediate Fix
Applied same day (commit `afab7930`, 2026-09-30 12:57:25, "fix: implement
dynamic version cache busting for curriculum & fix harness uuid bug") — moved
`import uuid` to the function's unconditional top-of-function import block in
`handle_paper_replication`, out of the `if event_type == "paper.archived":`
branch.

**Confirmed resolved 2026-10-05** while triaging `system_error_logs` via the
new `hbec-errors-mcp` tool: the 8 logged occurrences all fall between
2026-09-30T07:41 and 2026-10-01T07:00 — entirely before/at the fix commit,
consistent with normal deploy lag. None since. Tracker entries marked
resolved with a reference to this file.

### Long-term Fix
Move all standard library imports to the module level in the Agentic Harness handlers to avoid conditional import scoping issues.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- The user also inquired about student topics failing to sync, which was investigated alongside this and determined to be a reporting gap in the admin dashboard (not a real sync failure).

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
