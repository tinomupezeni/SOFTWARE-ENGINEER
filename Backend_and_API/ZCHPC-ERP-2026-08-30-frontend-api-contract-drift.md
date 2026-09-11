# Frontend API Contract Drift Broke Departments and Attendance Views

**Date:** 2026-08-30
**Project:** ZCHPC-ERP
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The deployed ZCHPC-ERP frontend called an attendance endpoint that returned `404 Not Found`, while the departments view raised `TypeError: fetchDepartments is not a function`. These related release-quality failures show that the frontend bundle and backend route/service contract were not verified together after deployment.

## Symptoms
- `GET /api/v2/all/attendance/` returned `404 Not Found`.
- The attendance page reported an Axios `ERR_BAD_REQUEST` caused by the 404.
- Department loading failed with `fetchDepartments is not a function`.
- The CLI history then requested another deployment after the branch had already been merged.

## Environment Details
- **Server/Host:** ZCHPC ERP VM, public frontend at `zchpcerp.zchpc.ac.zw`
- **Services Affected:** Frontend departments and attendance views
- **Related Components:** Frontend API client, attendance route, department service export, deployed bundle
- **Time First Observed:** 2026-08-30

## Investigation Steps

### 1. Initial Diagnosis
Compared browser bundle errors with requested backend paths and identified both a missing route response and a missing frontend function export.

### 2. Root Cause Analysis
The available CLI history confirms contract-mismatch symptoms but not the final source-level cause. The route, API prefix/version, frontend import/export, and deployed commit must be checked together.

### 3. Key Findings
- A successful frontend build did not prove the backend route existed.
- The frontend bundle referenced a function unavailable at runtime.
- Deployment was treated as complete before critical user journeys passed.

## Root Cause
Unconfirmed frontend/backend contract drift in the deployed release involving the attendance route and departments service export.

## Solution

### Immediate Fix
Verify the route table and frontend service exports on the exact deployed commit, add targeted contract tests, and rehearse the fix on staging before production promotion.

```bash
curl -i https://zchpcerp.zchpc.ac.zw/api/v2/all/attendance/
rg -n "fetchDepartments|all/attendance|api/v2" frontend backend
git rev-parse HEAD
```

### Long-term Fix
Generate or validate API contracts in CI, run deployed smoke tests for every critical frontend route, and make branch promotion depend on those tests rather than container startup alone.

## Prevention
- [ ] Establish one source of truth for API paths and service exports
- [ ] Add frontend/backend contract tests for attendance and departments
- [ ] Run critical journey smoke tests against staging before production
- [ ] Record deployed commit and image identity in the release report
- [ ] Block promotion when critical browser/API errors remain

## Related Issues
- Guide 8: End-to-End Testing
- Guide 18: Build Once, Deploy Everywhere
- Guide 19: Issue-to-Verified-Production Engineering Workflow

## References
- Antigravity CLI history, ZCHPC-ERP workspace, 2026-08-30

---

**Resolved By:** Not yet resolved in available history
**Time to Resolution:** Unknown
