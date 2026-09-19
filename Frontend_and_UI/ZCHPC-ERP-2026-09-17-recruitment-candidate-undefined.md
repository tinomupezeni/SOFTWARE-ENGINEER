# Recruitment Applications Render Crash (first_name undefined)

**Date:** 2026-09-17
**Project:** ZCHPC-ERP
**Environment:** Production (erp-vm)
**Severity:** High (Frontend Crash)
**Status:** Resolved

## Summary
Immediately following the fix for the `400 Bad Request` on the `/recruitment/jobs/{job_id}/applications/` endpoint, the frontend crashed with `TypeError: Cannot read properties of undefined (reading 'first_name')` inside the `ApplicantsModal.tsx` mapping loop.

## Root Cause
- The React frontend `ApplicantsModal.tsx` was expecting the API to return a deeply nested object for the candidate (`app.candidate.first_name`, `app.candidate.email`, etc.).
- The backend's DDD Application service and `ApplicationResponseSerializer` were instead returning a flat DTO (`candidate_name`, `candidate_email`). 
- Because `app.candidate` was completely undefined, accessing `app.candidate.first_name` threw a fatal React TypeError during the UI render phase.

## Solution
This required bridging the mismatch across both ends to maintain missing capabilities (like resume downloads):
1. **Backend Update**: Upgraded the `ApplicationDTO` dataclass in `providers.py` to include `candidate_phone`, `candidate_resume`, and `candidate_notes`. Mapped these fields in `application_service.py`'s `_to_dto` method, and added them to `ApplicationResponseSerializer`.
2. **Frontend Update**: Refactored `ApplicantsModal.tsx` to read the flat properties provided by the API:
   - `candidate_name`
   - `candidate_email`
   - `candidate_phone`
   - `candidate_resume`
   - `candidate_notes`
   - Replaced `{app.candidate.first_name[0]}` with safe string splitting `.split(' ')[0]?.[0]`.
   - Updated `applied_on` to `applied_at` to match the exact JSON key returned by the API.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code/Data changes required (Aligning frontend interfaces with backend DTOs)

---

**Resolved By:** Antigravity
**Time to Resolution:** 12 minutes
