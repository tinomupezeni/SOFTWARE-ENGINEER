# Staging User Management Shows No Last-Login Activity

**Date:** 2026-09-01
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Investigating

## Summary
The staging Admin User Management screen showed all users as `Never` logged in, including accounts that had been used for a long time. This indicates that authentication may be succeeding while the login-audit field is not being updated, or that the screen is reading a different user record/database than the authentication path.

## Symptoms
- User Management displayed active accounts with `Last Login: Never`.
- The report came from staging only; production was not included in the request.
- The issue was observed after the team had been actively logging into the system.

## Environment Details
- **Server/Host:** HBEC staging environment
- **Services Affected:** Admin User Management and login audit display
- **Related Components:** Admin frontend, authentication endpoint, user `last_login` persistence/query
- **Time First Observed:** 2026-09-01

## Investigation Steps

### 1. Initial Diagnosis
Compare the user record shown in staging with the record updated by a real staging login. Trace the login request through authentication, user persistence, and the User Management query.

### 2. Root Cause Analysis
The available CLI history confirms the discrepancy but does not establish whether the cause is missing persistence, a serializer/query field mismatch, stale frontend data, or different database connections.

### 3. Key Findings
- Authentication success and audit-record success are separate behaviors.
- A user-management page can look healthy while silently losing security-relevant login history.
- Staging must verify audit side effects, not only login response status.

## Root Cause
Undetermined; staging login activity is not appearing in the User Management `Last Login` field.

## Solution

### Immediate Fix
Perform one controlled staging login, query the exact user row before and after login, inspect the authentication response and backend logs, then reload the User Management data from the same staging database.

### Long-term Fix
Add an integration test asserting that a successful login updates `last_login`, and a staging smoke test asserting that the User Management screen displays the updated timestamp. Log which database and user identifier were used for the audit write.

## Prevention
- [ ] Trace and fix the missing `last_login` persistence or read path
- [ ] Add login-audit integration coverage
- [ ] Add staging smoke coverage for User Management audit fields
- [ ] Verify authentication and admin screens use the same staging database

## Related Issues
- Guide 19: Issue-to-Verified-Production Engineering Workflow

## References
- Antigravity CLI history, HBEC workspace, 2026-09-01

---

**Resolved By:** Not yet resolved in available history
**Time to Resolution:** Unknown
