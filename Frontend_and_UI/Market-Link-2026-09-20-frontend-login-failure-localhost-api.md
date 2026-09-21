# Uncommitted Hotfix Regression: API URL Domain Check

**Date:** 2026-09-20
**Project:** Market-Link
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
The login and registration issues for users on the `.hpc.ac.zw` domain regressed today. Two days ago, a hotfix was applied directly to the production VM to fix domain sniffing in `api.ts`. However, this fix was never committed to the source code repository. When the frontend container was rebuilt today, the hotfix was overwritten by the faulty code from the repository, causing the login issues to reappear.

## Symptoms
- Users on `agromarketing.hpc.ac.zw` experienced connection timeouts or SSL errors when attempting to log in.
- The browser console showed requests attempting to reach port `:5001`.

## Environment Details
- **Server/Host:** agromarketing-vm
- **Services Affected:** marketlink_frontend
- **Related Components:** `frontend/src/services/api.ts`
- **Time First Observed:** 2026-09-20

## Investigation Steps

### 1. Initial Diagnosis
Revisited the previous dev log from 2026-09-18 (`Market-Link-2026-09-18-api-url-domain-check-bug.md`). The log indicated that the issue was fixed by running a `sed` command directly on the VM's files to change the hardcoded domain string from `agromarketing.co.zw` to `agromarketing`.

### 2. Root Cause Analysis
Checked the git history for `frontend/src/services/api.ts` in the project repository. Discovered that the manual `sed` fix was never committed to version control. The repository still contained the broken code:
```typescript
const isDomain = window.location.hostname.includes('agromarketing.co.zw');
export const API_BASE_URL = isDomain 
  ? `${window.location.protocol}//${window.location.hostname}/api` 
  : `${window.location.protocol}//${window.location.hostname}:5001/api`;
```
When the container was recently rebuilt, it pulled the broken code from the repository, wiping out the uncommitted manual hotfix on the VM.

### 3. Key Findings
- The previous solution was a manual hotfix on the VM that wasn't committed to the codebase.
- Rebuilding the Docker image wiped out the manual hotfix.
- The "Long-term Fix" from the previous dev log was ignored.

## Root Cause
Configuration drift. An uncommitted hotfix applied directly to the production server was overwritten when the application was redeployed/rebuilt from version control.

## Prevention / Rule
**Guardrail:** Never modify code directly on production servers. All fixes must be committed to version control and deployed via the standard build process.

By ensuring the source of truth is always the Git repository, manual hotfixes cannot be accidentally overwritten by future deployments.

## Solution

### Immediate Fix
Implemented the previously recommended "Long-term Fix" directly in the source code repository. Refactored `frontend/src/services/api.ts` to properly use environment variables or a relative path, eliminating the flawed domain-sniffing logic entirely.

```typescript
export const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';
```

### Long-term Fix
Commit the fix to the repository and deploy it properly by pulling the latest code to the VM and rebuilding.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Regressed from: `Market-Link-2026-09-18-api-url-domain-check-bug.md`

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
