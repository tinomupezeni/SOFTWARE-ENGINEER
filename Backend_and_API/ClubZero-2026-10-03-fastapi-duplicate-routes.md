# FastAPI Duplicate Route Definition Overwriting

**Date:** 2026-10-03
**Project:** ClubZero
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The FastAPI backend `clubs.py` file was accidentally duplicated in its entirety within the same file. Because FastAPI processes route decorators sequentially, the second instance of the `get_club_stats` endpoint at the bottom of the file silently overwrote the updated `get_club_stats` endpoint defined earlier in the file, causing the API to continue serving stale logic despite code changes.

## Symptoms
- Flutter client threw `type 'bool' is not a subtype of type 'int' in type cast` when parsing the `/clubs/{club_id}/stats` response.
- Backend code was successfully patched to return `int` instead of `bool`, but the API still served `bool`.
- No syntax errors or application crashes were observed on the backend API server.

## Environment Details
- **Server/Host:** Local Docker Container (club-zero-backend-api-1)
- **Services Affected:** `get_club_stats` API Route
- **Related Components:** FastAPI routing
- **Time First Observed:** 2026-10-03

## Investigation Steps

### 1. Initial Diagnosis
Verified that the python file `clubs.py` contained the correct updated logic returning integers for the `history` array. Tested the endpoint using a raw script, which confirmed it still returned booleans.

### 2. Root Cause Analysis
Used `grep` to check for multiple definitions of the route:
```bash
grep -n "@router.get(" app/routers/clubs.py
```
Discovered that the entire file was duplicated starting around line 595, effectively resetting all routes to their original definitions.

### 3. Key Findings
- FastAPI allows defining the same path operation multiple times; the last defined operation for a specific method and path takes precedence.
- Python allows redeclaring functions with the same name without throwing syntax errors.

## Root Cause
An automated script (likely a `cat << 'EOF' >>` append instead of overwrite) accidentally appended the entire original file contents to the end of `clubs.py`, creating a duplicate set of routes that overwrote all previous route definitions.

## Prevention / Rule
**Guardrail:** Enforce a linter rule (e.g. `flake8` F811 `redefinition of unused name`) or a FastAPI specific route validator that crashes the server on startup if duplicate route paths are detected within the same router.

This will instantly surface any accidental route duplication or file appends during the build phase instead of failing silently at runtime.

## Solution

### Immediate Fix
Truncated the duplicate contents of `app/routers/clubs.py` to restore the file to its original length, then successfully patched the correct `get_club_stats` function.

### Long-term Fix
Ensure file patching tools rely on exact line numbers and `sed -i` replacements rather than appending to files or using loose `>>` operators.

## Related Issues
- None

---

**Resolved By:** Antigravity
**Time to Resolution:** 15m
