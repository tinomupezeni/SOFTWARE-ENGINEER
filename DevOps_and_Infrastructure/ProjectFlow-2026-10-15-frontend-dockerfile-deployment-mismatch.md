# Deployment referenced a missing frontend Dockerfile

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Development/Deployment
**Severity:** Medium
**Status:** Resolved

## Summary
The staging deployment script referenced `../projectflow-hq/Dockerfile.prod`, but the frontend checkout only contained `Dockerfile`. The first deployment attempt built the backend successfully and stopped before uploading images or changing the VPS.

## Symptoms
- Frontend image build failed with `failed to read dockerfile: open Dockerfile.prod: no such file or directory`.
- No remote containers were changed during the failed attempt.

## Environment Details
- **Server/Host:** Local build host; deployment target `restk-vps`
- **Services Affected:** Frontend image build
- **Related Components:** `deploy.sh`, `../projectflow-hq/Dockerfile`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Checked the frontend directory after the deployment script failed.

### 2. Root Cause Analysis
The deployment script had been updated to use a production-specific Dockerfile that was not present in the frontend repository checkout.

```bash
find ../projectflow-hq -maxdepth 2 -type f -name 'Dockerfile*'
```

### 3. Key Findings
- Available frontend file: `../projectflow-hq/Dockerfile`.
- Missing file: `../projectflow-hq/Dockerfile.prod`.
- The existing Dockerfile produced the frontend image successfully on retry.

## Root Cause
The backend deployment script and frontend repository did not share a validated Dockerfile contract.

## Prevention / Rule
**Guardrail:** Add a deploy preflight that verifies every referenced Dockerfile exists before building and fails with the resolved path.

This catches repository/script drift before any image upload or production replacement begins.

## Solution

### Immediate Fix
Changed `deploy.sh` to build the frontend with the available `../projectflow-hq/Dockerfile`.

### Long-term Fix
Keep frontend build artifacts and deployment scripts versioned together or validate the cross-repository Dockerfile path in CI.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-source-rollback-risk.md`

## References
- ProjectFlow commit `ca7843e`
- `projectflow_backend/deploy.sh`
- `projectflow-hq/Dockerfile`

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
