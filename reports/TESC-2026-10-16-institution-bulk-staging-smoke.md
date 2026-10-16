# TESC institution bulk-upload staging smoke verification

**Date:** 2026-10-16
**Project:** TESC
**Type:** Testing / Verification
**Status:** Completed

## Summary
Reran the institution-side bulk-upload smoke suite against the requested
staging domains. All 14 upload flows passed, and the institution frontend
hostname served its root and representative routes successfully.

## Context / Trigger
The previous smoke harness defaulted to localhost and used stale institution
authentication assumptions. The request was to verify the current deployed
staging services at `tesc-staging.zchpc.ac.zw` and
`tesc-inst-staging.zchpc.ac.zw`.

## Scope
Covered ingestion template download, spreadsheet validation, and commit for
11 ingestion modules; custom student, staff, and graduate uploads; specialized
and critical student result endpoints; and representative institution frontend
routes.

## Method
Used the backend virtual environment to execute the smoke harness with
`TEST_BASE_URL=https://tesc-staging.zchpc.ac.zw/api`. The harness created an
isolated institution and related records, authenticated as the institution
administrator through `/instauth/login/`, executed each flow, verified result
records, and cleaned up the test institution. Frontend availability was
checked separately on the institution hostname.

## Decisions & Findings
- The staging API hostname is the correct target for backend upload requests.
- Institution authentication requires `/instauth/login/` and the `username`
  field, not the main user token endpoint.
- All tested upload flows passed after applying the current input-validation
  changes.
- `https://tesc-inst-staging.zchpc.ac.zw/`, `/login`, and `/students` each
  returned HTTP 200.

## Changes Made
- Updated `smoke_test_all_bulk_uploads.py` to default to the API staging
  hostname and use the institution login field expected by staging.
- Recorded 14 PASS entries in the session endpoint checklist.
- TESC commit: `55e23a1`.

## Verification
- 14/14 institution bulk-upload flows passed:
  faculties, programs, STEM students, specialized students, critical students,
  inclusivity, possible graduates, placements, scholarships, mobility,
  in-country transfers, custom students, custom staff, and custom graduates.
- Specialized-student and critical-student API checks passed.
- Test institution cleanup completed successfully.
- Institution frontend root, `/login`, and `/students` returned HTTP 200.

## Follow-ups / Deferred
- Run the negative/adversarial bulk-upload suite against the same two staging
  hosts to verify malformed dates, IDs, email addresses, phone numbers, and
  numeric bounds are rejected.
- Keep the endpoint checklist synchronized with future staging smoke runs.

## References
- `smoke_test_all_bulk_uploads.py`
- Session table: `endpoint_checklist`
- TESC commit `55e23a1`

---

**Completed By:** Copilot
**Duration:** Same session
