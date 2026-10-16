# TESC Institution Bulk-Upload Verification

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Type:** Audit / End-to-end verification
**Status:** Completed

## Summary
Verified the institution-side bulk-upload functionality against the deployed staging backend. All 14 bulk-upload flows passed after aligning the temporary smoke harness with the current authentication, spreadsheet-template, and response contracts. The institution frontend production build passed; frontend test and lint findings remain separately recorded.

## Context / Trigger
After repairing the staging email and Celery runtime, the next required confidence check was a complete test of institution-side bulk uploads.

## Scope
Included backend API end-to-end testing through the deployed staging containers and institution frontend build/test/lint checks. Browser-based Playwright upload flows were not run because no existing Playwright bulk-upload scenario was identified in the institution test suite.

## Method
1. Ran the complete `smoke_test_all_bulk_uploads.py` flow inside the staging backend container.
2. Created and removed isolated test institutions and related data per run.
3. Covered template download, validation, commit, custom upload endpoints, and specialized/critical API verification.
4. Installed institution frontend dependencies and ran Vitest, Vite build, and ESLint.

## Decisions & Findings
- All 14 backend bulk-upload paths passed:
  - Faculties
  - Programs
  - STEM students
  - Specialized students
  - Critical students
  - Inclusivity
  - Possible graduates
  - Placements
  - Scholarships
  - Mobility
  - In-country transfers
  - Custom students
  - Custom staff
  - Custom graduates
- The committed smoke harness has stale assumptions and was temporarily adapted for this verification; see the related issue record.
- The institution frontend production build passed.
- The frontend Vitest suite had 32 passing tests and 7 AddStudentDialog timeouts.
- ESLint reported existing explicit-`any` errors outside the bulk-upload API path.

## Changes Made
- No production application code was changed for the bulk-upload verification.
- Temporary test copies were adapted inside the staging container only.
- Findings were recorded in the engineering issue logs.

## Verification
- Staging backend, PostgreSQL, Redis, and Celery worker were running.
- All Django-backed bulk upload flows completed successfully.
- Test institutions were cleaned up after each run.
- `inst npm run build`: passed.
- `inst npm test -- --run`: 32 passed, 7 failed by timeout.
- `inst npm run lint`: failed on existing explicit-`any` violations.

## Follow-ups / Deferred
- Update the committed bulk-upload smoke harness to use current contracts.
- Investigate and fix the 7 `AddStudentDialog` test timeouts and `act(...)` warnings.
- Add browser-level institution upload tests if UI-level coverage is required.
- Resolve existing institution frontend lint errors.

## References
- `TESC-2026-10-16-bulk-upload-smoke-harness-drift.md`
- `TESC-2026-10-16-institution-frontend-tests-timeout.md`
- `tests/smoke_tests/smoke_test_all_bulk_uploads.py`
- `backend/academic/services/ingestion_service.py`

---

**Completed By:** Copilot
**Duration:** One staging verification session
