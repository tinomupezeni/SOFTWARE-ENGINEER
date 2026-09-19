# API URL Domain Check Bug Blocking HPC Domain Users

**Date:** 2026-09-18
**Project:** Market-Link
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
Users accessing the frontend via `agromarketing.hpc.ac.zw` were failing to log in or register because their API requests were being incorrectly routed to port 5001 instead of the standard `/api` proxy path.

## Symptoms
- Users on `agromarketing.hpc.ac.zw` experienced connection timeouts or SSL errors when attempting to log in.
- The browser console showed network errors on `fetch` requests.

## Environment Details
- **Server/Host:** agromarketing-vm
- **Services Affected:** Frontend UI (React), Backend API connectivity
- **Related Components:** `frontend/src/services/api.ts`
- **Time First Observed:** 2026-09-18

## Investigation Steps

### 1. Initial Diagnosis
Checked if users could log in via the `agromarketing.co.zw` domain. Using `curl` with a POST to `https://agromarketing.co.zw/api/auth/login` succeeded, but `https://agromarketing.hpc.ac.zw:5001/api/auth/login` failed due to port restrictions.

### 2. Root Cause Analysis
Inspected `api.ts` in the frontend codebase to see how it constructs the `API_BASE_URL`.
```typescript
const isDomain = window.location.hostname.includes('agromarketing.co.zw');
export const API_BASE_URL = isDomain 
  ? `${window.location.protocol}//${window.location.hostname}/api` 
  : `${window.location.protocol}//${window.location.hostname}:5001/api`;
```
Because the condition explicitly checked for `agromarketing.co.zw`, users on `agromarketing.hpc.ac.zw` caused `isDomain` to evaluate to `false`, appending `:5001` to the API URL. The external firewall blocks port 5001.

### 3. Key Findings
- The hardcoded domain check fails for alternative domains pointing to the same service.
- Port 5001 is closed externally; requests must go through the proxy path `/api` on standard web ports.

## Root Cause
Hardcoded logic for determining production environment based on an exact domain name subset (`.co.zw`), failing to account for alternative domain configurations (`.hpc.ac.zw`).

## Prevention / Rule
**Guardrail:** Remove domain-sniffing for API URL construction. 

Use environment variables (e.g. `REACT_APP_API_URL`) defined at build/runtime rather than guessing based on `window.location.hostname`. If relative routing is used (like a proxy), simply use `/api` as the base URL relative path so it naturally respects whatever host the browser is currently on.

## Solution

### Immediate Fix
Updated `api.ts` to check for just `agromarketing` instead of `agromarketing.co.zw`, supporting both the `.co.zw` and `.hpc.ac.zw` domains.

```bash
sed -i 's/agromarketing\.co\.zw/agromarketing/g' Documents/agromarket/frontend/src/services/api.ts
```

### Long-term Fix
Refactor the frontend to either use a relative path (`/api`) entirely, or use proper environment variables injected at build time.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Related to users failing to login due to API request failure.

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 mins
