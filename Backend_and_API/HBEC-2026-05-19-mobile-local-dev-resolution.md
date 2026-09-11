# Mobile Local Development Environment and Build Resolution

**Date:** 2026-05-19
**Project:** HBEC
**Environment:** Local/Android Emulator
**Severity:** Moderate
**Status:** Resolved

## Summary
The HBEC Student Mobile app build was hanging at 100% bundling due to a configuration conflict. The app was defaulting to the production API URL (https://student.hbca.tech/api) in a local development context, causing network timeouts and preventing successful initialization.

## Symptoms
- Build process stalled indefinitely at 100% bundling.
- App unable to reach backend when launched on emulator.
- Metro bundler hanging on initial hydration.

## Environment Details
- **Host OS:** win32
- **Emulator:** Android (emulator-5554)
- **Framework:** Expo SDK 51 / React Native 0.74.5
- **Backend:** Django (0.0.0.0:8000)

## Investigation Steps

### 1. Initial Diagnosis
Checked background output of the 
pm run android command and db logcat. Found the app was successfully installed but hung during the first network request.

### 2. Root Cause Analysis
- Inspected .env and found it was hardcoded to https://student.hbca.tech/api.
- Verified that the emulator was trying to resolve this domain but failed due to lack of production DNS/proxy mapping in the local dev environment.
- Confirmed that db reverse was missing, preventing the emulator from seeing localhost:8000.

### 3. Key Findings
- Manual "band-aid" fixes (editing .env directly) are high-risk for production deployments.
- Database seeding logic for Subject models was fragile, failing on grade field mismatches during local setup.

## Root Cause
Configuration defaults were set to production without a local override strategy, combined with missing network bridging between the Android guest and host machine.

## Solution

### Immediate Fix
- Implemented a layered environment strategy using .env.development for local overrides.
- Established db reverse tcp:8000 tcp:8000 to bridge the emulator to the local backend.
- Manually corrected database seeding scripts to match the current ZIMSEC curriculum schema (Subject level mapping).

### Long-term Fix
Adopt a "Zero-Reconfiguration Deployment" standard where production settings are the default, and local overrides are handled via environment-specific .env files that are excluded from production bundles but loaded automatically in dev.

## Prevention
- [x] Layered .env strategy implemented
- [x] Network bridging (adb reverse) documented
- [x] Database seeding logic verified locally

## Related Issues
- Mobile Production Connectivity and Token Refresh Bugs (2026-05-12)

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 30 minutes
