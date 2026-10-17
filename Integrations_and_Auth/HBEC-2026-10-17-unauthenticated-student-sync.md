# Unauthenticated Student Synchronization Endpoint

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** Source audit; deployment exposure not yet verified
**Severity:** High
**Status:** Investigating

## Summary
`SyncStudentView` is mounted at `/api/internal/sync-student/` with `AllowAny` and does not call the existing `InternalAuthMixin` verifier. An unauthenticated caller can submit student identity, password, grade, and institution fields, then create or update a student account and institution sponsorship.

## Symptoms
- An internal account-provisioning route accepts unauthenticated requests.
- The view contains a comment acknowledging that internal authentication was omitted.

## Environment Details
- **Server/Host:** HBEC Student Backend
- **Services Affected:** `STUDENT/hbec_backend`
- **Related Components:** Internal API, student accounts, institution sponsorships
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Traced the route from the root URL configuration through the internal URL module to the view and compared it with neighboring views that invoke `check_internal_auth`.

### 2. Root Cause Analysis
`apps/internal/views.py:291-347` declares `permission_classes = [AllowAny]`; it reads attacker-controlled fields and writes `User`, `StudentProfile`, and `InstitutionSponsorship` records. Neighboring internal views use `InternalAuthMixin`, but this view does not.

### 3. Key Findings
- `STUDENT/hbec_backend/config/urls.py:21-22`
- `STUDENT/hbec_backend/apps/internal/urls.py:17-22`
- `STUDENT/hbec_backend/apps/internal/views.py:291-347`
- Existing verifier: `STUDENT/hbec_backend/apps/internal/views.py:103-137`

## Root Cause
The account-provisioning endpoint relies on an assumed private network instead of enforcing service authentication at the application boundary.

## Prevention / Rule
**Guardrail:** Every endpoint under `/api/internal/` must inherit the internal-authentication gate, and CI must include a route test proving unsigned requests cannot mutate account or sponsorship state.

This closes the exact omission pattern where a newly added internal route is reachable without the shared HMAC control.

## Solution

### Immediate Fix
Verify public reachability and block the route at the edge if exposed. Rotate or repair any accounts and sponsorships created through unauthorized requests.

### Long-term Fix
Apply `InternalAuthMixin` or the repository's equivalent direction-bound service signature to `SyncStudentView`, validate the caller as the schools service, and add tests for unsigned, wrong-key, and valid signed requests.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## References
- `STUDENT/hbec_backend/config/urls.py:21-22`
- `STUDENT/hbec_backend/apps/internal/urls.py:17-22`
- `STUDENT/hbec_backend/apps/internal/views.py:291-347`
- `STUDENT/hbec_backend/apps/internal/views.py:103-137`

---

**Resolved By:** Pending
**Time to Resolution:** Pending
