# Projectflow helper scripts emitted raw stdout

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development working tree; not previously committed
**Severity:** Low
**Status:** Resolved

## Summary
Two untracked Projectflow helper scripts used `print()` for task results and failures, conflicting with the HBEC JSON logging rule for stdout.

## Symptoms
- Task results and failures would appear as unstructured text without trace fields.

## Environment Details
- **Server/Host:** Local HBEC checkout
- **Services Affected:** Projectflow helper scripts and operational logs
- **Related Components:** `get_task_info.py`, `reply_task.py`, `projectflow_cli.py`
- **Time First Observed:** 2026-11-08 pre-commit review

## Investigation Steps

### 1. Initial Diagnosis
Read the untracked helper scripts during pre-commit inspection.

### 2. Root Cause Analysis
Both scripts called `print()` directly and had no configured logger.

### 3. Key Findings
- All result and error output bypassed structured logging.
- The scripts were untracked and were corrected before commit.

## Root Cause
One-off helper scripts did not use the repository's operational logging convention.

## Prevention / Rule
**Guardrail:** Reject `print()` calls in operational scripts with a repository lint rule.

This closes the gap for small root-level helpers that service lint targets may omit.

## Solution

### Immediate Fix
Added a shared standard logging instance with JSON serialization and `trace_id`, `span_id`, and `service.name`; caught exceptions use `.exception()` with structured error fields. Removed raw `print()` calls.

### Long-term Fix
Add the lint guardrail to CI; it remains pending.

## Prevention
- [x] Code changes required
- [ ] Lint guardrail added

## Related Issues
- See `Integrations_and_Auth/HBEC-2026-11-08-projectflow-helper-hardcoded-credentials.md`.

## References
- HBEC `get_task_info.py`, `reply_task.py`, `projectflow_cli.py`

---

**Resolved By:** Local code fix
**Time to Resolution:** 2026-11-08
