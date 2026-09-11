# Mobile Production Connectivity and Token Refresh Bugs

**Date:** 2026-05-12
**Project:** HBEC
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
During a specialized audit of the HBEC Student Mobile App, multiple critical bugs were identified that would have prevented successful connection to the production backend and caused permanent session disconnection after 60 minutes in production environments.

## Symptoms
- Mobile app unable to reach backend API in production builds.
- Silent token refresh failing, leading to 401 Unauthorized errors after access tokens expire.
- Inconsistent API base URLs across different modules causing partial service failures.

## Environment Details
- **Server/Host:** student.hbca.tech
- **Services Affected:** Student Mobile App, Student Backend (Auth), Agentic Harness
- **Related Components:** eas.json, src/utils/api.ts, src/api/harness.ts
- **Time First Observed:** 2026-05-12 (during audit)

## Investigation Steps

### 1. Initial Diagnosis
Checked eas.json for environment variable alignment and pi.ts for backend URL fallbacks.

### 2. Root Cause Analysis
- Inspected eas.json and found API_URL was used instead of the mandatory EXPO_PUBLIC_API_URL for Expo SDK 51.
- Analyzed harness.ts and discovered hardcoded references to incorrect backend endpoints (/accounts/token/refresh/) and non-matching JSON property names (efresh).

### 3. Key Findings
- Missing EXPO_PUBLIC_ prefix on environment variables prevented them from being embedded in the production JS bundle.
- Production domain in config (hbca.tech/api) mismatched the proxy configuration (student.hbca.tech/api).
- Token refresh logic in the AI Harness client used legacy endpoint paths and property names.

## Root Cause
Configuration drift between the mobile app's environment definitions and the production backend/proxy infrastructure, combined with legacy code in the AI Harness client that was not updated during the Auth refactor.

## Solution

### Immediate Fix
- Updated eas.json with correct EXPO_PUBLIC_ prefixes and production domains.
- Created a centralized configuration module (src/config/index.ts) to eliminate hardcoded URL sprawl.
- Refactored pi.ts and harness.ts to use the unified config and correct backend refresh endpoints.

### Long-term Fix
Centralize all environment-sensitive configuration into a single module and enforce a "Single Source of Truth" policy for API endpoints across all services.

## Prevention
- [x] Configuration changes implemented
- [ ] Add pre-build validation script to check environment variable alignment
- [x] Documentation updated in src/config/index.ts
- [x] Code changes verified against backend API specs

## Related Issues
- Production Connectivity Audit

## References
- Expo SDK 51 Environment Variable Documentation
- HBEC Student Backend API Specs (accounts/views.py)

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 45 minutes
