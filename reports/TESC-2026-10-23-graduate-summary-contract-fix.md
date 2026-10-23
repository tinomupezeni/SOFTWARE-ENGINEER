# TESC Graduate Summary Contract Fix

**Date:** 2026-10-23
**Project:** TESC
**Type:** Bug Fix / API Contract
**Status:** Completed

## Summary
Aligned the institution Student Statistics summary with the Graduates page by
restoring graduation outcome fields in the lightweight student API response.

## Context / Trigger
The institution staging Graduates page showed 14 passed and 2 failed records,
while Student Statistics showed zero for both metrics.

## Scope
Included the backend lightweight student response, frontend consumer contract,
staging verification, and regression fixture. No database records or frontend
business logic were changed.

## Method
Traced both pages' API paths, compared the frontend predicates with the backend
payload, added the missing response fields, and ran the corrected targeted test
against staging.

## Decisions & Findings
- `all-light` is the source for the Student Statistics summary.
- `final_grade` and `graduation_year` are required contract fields.
- The issue was response-shape drift, not incorrect graduation data.

## Changes Made
- Added `graduation_year` and `final_grade` to `StudentViewSet.all_light`.
- Added an assertion for those fields to `backend/test_dashboard_stats.py`.
- Corrected the fixture to create required `Person` records.
- Transferred the backend fix to staging.

## Verification
- Staging dashboard stats test: passed.
- Staging `all-light` contract smoke: HTTP 200 and both required fields present.
- Institution staging portal: HTTP 200.
- Django system check: passed.
- Backend, database, and Redis containers remained running.

## Follow-ups / Deferred
- The UI should be refreshed or rebuilt only if other frontend changes are
  introduced; this fix is served by the bind-mounted backend API.

## References
- `Backend_and_API/TESC-2026-10-23-graduate-summary-contract-drift.md`
- `backend/academic/app_views/student_views.py`
- `inst/src/pages/Students.tsx`

---

**Completed By:** Copilot
**Duration:** Same session
