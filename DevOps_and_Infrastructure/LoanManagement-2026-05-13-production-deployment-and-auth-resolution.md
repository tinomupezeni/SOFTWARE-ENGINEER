# Production Deployment Failures and Authentication Mismatch

**Date:** 2026-05-13
**Project:** LoanManagement
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The production deployment encountered multiple failures including Docker build DNS errors, smoke test failures due to API structure mismatch, and authentication failures caused by a password desynchronization on the VPS.

## Symptoms
- Docker build failed with Could not resolve 'deb.debian.org' in dmin-api.
- Smoke tests failed with 404/405 errors on /api/clients/, /api/loans/, etc.
- Smoke tests failed with 401 Unauthorized on authentication endpoints.
- VPS containers were running but the application was functionally inaccessible via automated tests.

## Environment Details
- **Server/Host:** VPS (159.198.42.231)
- **Services Affected:** admin-api, agent-api, smoke-tests
- **Related Components:** Docker Build (Debian mirrors), Django URL routing, JWT Authentication.
- **Time First Observed:** 2026-05-13 08:00 AM

## Investigation Steps

### 1. Initial Diagnosis
- Ran .\scripts\mlms.ps1 which reported a build failure in dmin-api step 3/8.
- Inspected build logs and identified a DNS/mirror resolution error inside the container.

### 2. Root Cause Analysis
- **DNS Error:** The default python:3.12-slim image was pulling from Debian "Trixie" (Testing) mirrors which were experiencing resolution issues.
- **404/405 Errors:** Smoke tests were hardcoded to legacy URL patterns (e.g., /api/clients/) while the actual API used restructured paths (e.g., /api/clients/list/).
- **401 Errors:** The seed_admin command on the VPS had not correctly updated the password to match the one expected by the smoke test runner.

`ash
# Check container logs
docker logs mlms-admin-api --tail 50
# Verify migrations
docker exec mlms-admin-api python manage.py makemigrations
`

### 3. Key Findings
- Container DNS issues are prevalent on the current host/Docker Desktop setup.
- The backend API structure had evolved but the verification suite (smoke tests) had not been synchronized.
- Deployment diagnostics (mlms.ps1 diagnose) used incorrect container names (mlms-admin-db-1 vs mlms-admin-db).

## Root Cause
1. **Network Instability:** Unstable Debian testing mirrors in the base Docker image.
2. **Schema Drift:** Decoupling between API implementation and automated verification scripts.
3. **Auth Desync:** Password mismatch between VPS database state and deployment script parameters.

## Prevention / Rule
**Guardrail:** (1) Pin every Dockerfile's base image to a named stable
release (`-bookworm`, never a rolling/testing codename) via a lint rule
that rejects unpinned or testing-channel base images in CI. (2) Run the
smoke test suite against the same OpenAPI/URL spec the API itself is
generated from (or fail CI if a route the smoke tests hit doesn't exist in
the current spec), so the two can't silently diverge. (3) Have the seed
script read the same credential value the smoke-test runner uses (a single
shared secret/config source), instead of two independently-set passwords
that can drift apart.

Each of the three root causes maps to a mechanism that would have caught it
before it reached production: pinned base images stop the mirror
instability, spec-driven smoke tests stop route drift, and one shared
credential source stops the auth desync.

## Solution

### Immediate Fix
- Switched base images to python:3.12-slim-bookworm (Stable) and added pt-get retries.
- Updated smoke_tests.py with the correct RESTful endpoints.
- Forcibly reset the admin password on the VPS via a temporary Django shell script.
- Corrected container names in mlms.ps1 diagnostics.

`ash
# Force password reset on VPS
docker exec -i mlms-admin-api python manage.py shell <<EOF
from apps.users.models import User
u = User.objects.get(email='admin@restksolutions.co.zw')
u.set_password('Pr0b!tasAdmin2026$')
u.save()
EOF
`

### Long-term Fix
- Use explicit stable versions for all base images.
- Include smoke test updates as a mandatory step in the API refactoring workflow.

## Prevention
- [x] Configuration changes needed (Dockerfile base images)
- [ ] Monitoring/alerts to add
- [x] Documentation to update (API endpoint changes)
- [x] Code changes required (Smoke tests)

## Related Issues
- N/A

## References
- Docker DNS troubleshooting documentation
- MLMS REST API Documentation

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 2 hours
