# [TESC] Institution Bulk-Upload Smoke Harness Drifted from API Contracts

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** Medium
**Status:** Workaround Applied

## Summary
The institution bulk-upload smoke harness contained several stale assumptions that caused false failures before or during coverage: it used the main user login endpoint for institution admins, expected HTTP 201 for a student upload that correctly returns HTTP 200, used legacy program spreadsheet headers, and attempted to upload a graduate record for a nonexistent student.

## Symptoms
- Institution admin login returned 403/401.
- Program validation reported missing `Levels`, `Categories`, and `Program Type`.
- Custom student upload returned success with HTTP 200 but the test required 201.
- Graduate upload correctly rejected a missing student ID.

## Environment Details
- **Server/Host:** TESC staging Docker runtime
- **Services Affected:** Institution smoke-test coverage
- **Related Components:** `tests/smoke_tests/smoke_test_all_bulk_uploads.py`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran the complete institution bulk-upload suite against the deployed staging backend.

### 2. Root Cause Analysis
Compared each failing test assumption with the active endpoint and ingestion schemas. The API behavior was consistent; the smoke script had not been updated after auth, template, and response-contract changes.

### 3. Key Findings
- Institution admins must authenticate through `/api/instauth/login/`.
- Program ingestion currently generates `Levels`, `Categories`, and `Program Type` headers.
- Custom student upload returns a successful HTTP 200 response.
- Graduate upload requires an existing student belonging to the institution.

## Root Cause
The smoke harness duplicated API contracts instead of deriving or asserting against the current endpoint behavior, so it accumulated stale assumptions.

## Prevention / Rule
**Guardrail:** Bulk-upload smoke tests must obtain field names from the downloaded server template and assert documented success semantics rather than hard-coded legacy headers/status codes.

This keeps the end-to-end gate aligned with the API contract and prevents valid uploads from being reported as failures.

## Solution

### Immediate Fix
Applied temporary harness adjustments during this run:
- Used institution authentication with the smoke-test header.
- Used current program template headers.
- Accepted HTTP 200/201 for custom student upload.
- Reused an existing test student for graduate upload.

### Long-term Fix
Update the committed smoke harness with these contract-aligned behaviors and add cleanup/assertions for every created entity.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- None.

## References
- `tests/smoke_tests/smoke_test_all_bulk_uploads.py`
- `backend/academic/services/ingestion_service.py`
- `backend/instauth/services/auth_service.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same test session
