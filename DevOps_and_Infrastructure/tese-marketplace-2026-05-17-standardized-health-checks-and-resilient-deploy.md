# Structural Fix: Deployment Robustness and Health Check Standardization

**Date:** 2026-05-17
**Project:** Tese-Marketplace
**Environment:** Production (VPS)
**Severity:** High
**Status:** Resolved (Fix applied)

## Summary
The deployment script `tese.ps1` was identified as having fragile health check logic and insufficient resilience to network instability. The Python fallback mechanism was causing PowerShell syntax errors locally, and the image pull process lacked retries, leading to partial deployments during VPS network brownouts.

## Symptoms
- **PowerShell Error:** `The term '\import urllib.request, sys; \' is not recognized`.
- **Deployment Failure:** `Service store-api failed deep health check!` followed by script termination.
- **Docker Error:** `TLS handshake timeout` during pulls.

## Investigation Steps
1. Audited `tese.ps1` and identified broken quote escaping in the `Verify-Deployment` function.
2. Verified that all microservice Dockerfiles now include `curl`.
3. Observed that the VPS network is unstable, causing intermittent pull failures.

## Root Cause
1. **Scripting Architecture:** The script used complex escaped strings for a Python fallback that is no longer necessary now that all images contain `curl`.
2. **Lack of Resilience:** The deployment process assumed perfect network conditions for image pulls and service startup.

## Solution

### Immediate Fix
- Refactored `tese.ps1` to remove the Python fallback and use standardized `curl` health checks.
- Improved the health check loop to retry up to 5 times with a 5-second delay between attempts.

### Long-term Fix
- **Standardized Health Checks:** Standardized on `curl -sf http://localhost:8000/api/v1/health/deep` across the entire fleet.
- **Pull Resilience:** Updated `tese.ps1` to retry `docker compose pull` up to 3 times on failure.
- **Robust Shell Handling:** Simplified SSH command construction to avoid nested quote hell.

## Prevention
- Standardized Docker base layers to always include `curl`.
- Enforce the use of simple, verifiable health check commands.

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 30 minutes
