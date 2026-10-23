# TESC Institution Graduation Summary Frontend Refresh

**Date:** 2026-10-23
**Project:** TESC
**Type:** Deployment Fix
**Status:** Completed

## Summary
Refreshed the institution staging frontend so Student Statistics executes the
current graduation summary logic and no longer shows zero passed/failed counts
when the backend contains valid outcomes.

## Context / Trigger
The backend contract fix was present and staging records were correct, but the
live institution page continued to display PASSED 0 and FAILED 0.

## Scope
Included staging data verification, backend response verification, institution
frontend artifact inspection, image rebuild, container recreation, and live
route verification. No production services or data were changed.

## Method
Compared database counts, live endpoint fields, running image/container
identity, and served JavaScript markers; rebuilt only the institution frontend
service and verified the public asset.

## Decisions & Findings
- Failed outcomes are not counted as graduated passing outcomes.
- ZCHPC has 14 passed and 2 failed records.
- The mismatch was caused by a stale frontend image, not data or backend logic.

## Changes Made
- Rebuilt `ghcr.io/tinomupezeni/tesc-inst:latest` from current staging source.
- Recreated the institution frontend service.

## Verification
- ZCHPC database counts: 14 passed, 2 failed.
- Live `/all-light/` payload: includes outcome fields and classifies 14/2.
- Served institution bundle: contains `all-light` and `finalGrade` references.
- Institution dashboard/students route: HTTP 200.

## Follow-ups / Deferred
- Replace mutable `latest` frontend deployment with immutable image tags and
  record the exact digest in future promotion reports.
- The older orphan institution container remains on the host; routing currently
  serves the refreshed asset, but orphan cleanup should be handled separately
  under controlled deployment maintenance.

## References
- `Frontend_and_UI/TESC-2026-10-23-stale-institution-frontend-graduation-summary.md`
- `Backend_and_API/TESC-2026-10-23-graduate-summary-contract-drift.md`
- `inst/src/pages/Students.tsx`

---

**Completed By:** Copilot
**Duration:** Same session
