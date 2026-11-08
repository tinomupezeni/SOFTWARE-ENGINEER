# Projectflow helper scripts embedded account credentials

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development working tree; not previously committed
**Severity:** High
**Status:** Investigating

## Summary
Two untracked Projectflow task helper scripts in the HBEC working tree contained a literal login password and account email. Committing the files unchanged would publish the credential in repository history.

## Symptoms
- The scripts supplied a credential directly in the login request source.
- Anyone with read access to the repository could recover it after a commit.

## Environment Details
- **Server/Host:** Local HBEC checkout
- **Services Affected:** Projectflow account authentication
- **Related Components:** `get_task_info.py`, `reply_task.py`
- **Time First Observed:** 2026-11-08 pre-commit review

## Investigation Steps

### 1. Initial Diagnosis
Inspected all untracked scripts before staging the working tree.

### 2. Root Cause Analysis
The one-off scripts encoded the login request with literal credentials rather than environment-supplied values.

### 3. Key Findings
- The files were untracked, so the credential was not part of the HBEC commit being pushed.
- The credential's validity and any use elsewhere were not verified.

## Root Cause
Ad hoc integration scripts lacked a rule requiring credentials to come from the environment.

## Prevention / Rule
**Guardrail:** Run a secret scanner on staged files in CI or a pre-commit hook and reject literal account credentials before commit.

The scanner must cover root-level helper scripts as well as application directories, because these files sat outside the service code.

## Solution

### Immediate Fix
Replaced literal email and password with required `PROJECTFLOW_EMAIL` and `PROJECTFLOW_PASSWORD` environment variables in the shared helper client. A staged-content credential scan found no literal in these scripts.

### Long-term Fix
Rotate the credential if it is still active, and add the staged-file secret scanner. Rotation has not been verified.

## Prevention
- [x] Code changes required
- [ ] Credential rotation verified
- [ ] Secret-scanning guardrail added

## Related Issues
- The same scripts also emitted raw stdout; see `DevOps_and_Infrastructure/HBEC-2026-11-08-projectflow-helper-raw-stdout.md`.

## References
- HBEC `get_task_info.py`, `reply_task.py`, `projectflow_cli.py`

---

**Resolved By:** Local code fix; credential rotation pending
**Time to Resolution:** Local code fix on 2026-11-08
