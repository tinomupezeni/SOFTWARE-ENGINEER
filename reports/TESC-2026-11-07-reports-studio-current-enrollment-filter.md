# Reports Studio Current Enrollment Filter

**Date:** 2026-11-07
**Project:** TESC
**Type:** Feature / Reporting Contract
**Status:** Completed

## Summary
Added the existing Current Enrollment Only business rule to Reports Studio. Users can now scope supported reports, visualizations, CSV/Excel exports, and PDFs to regular students whose enrollment year plus programme duration extends beyond the current year.

## Context / Trigger
Reports Studio had advanced filters but did not expose the same Current Enrollment Only mechanism used by student, inclusivity, specialized, STEM, scholarship, and critical-student views.

## Scope
Included the Studio frontend filter, report-engine enforcement, supported-source handling, regression tests, and idle-color deployment. Excluded changes to the canonical enrollment rule, ISEOP inclusion, database schema, and blue-green cutover.

## Method
Traced the established rule to `duration_enrolled_queryset`, then added it as a top-level report definition flag. The ReportEngine applies it to regular student reports and student-related sources; unsupported sources fail explicitly instead of silently ignoring the request.

## Decisions & Findings
- Current enrollment remains `enrollment_year + programme duration > current year`.
- All student statuses remain eligible.
- Regular students only are included; ISEOP is excluded by the canonical selector.
- Supported sources are students, graduates, scholarships, industry placements, international mobility, and in-country transfers.
- The same flag is included in table, chart, export, and PDF requests.

## Changes Made
- Commit `1a6c3e7` pushed to `tinomupezeni/TESC` branch `staging`.
- Updated `backend/reports/engine.py`.
- Added focused engine tests in `backend/reports/tests.py`.
- Updated `frontend/src/pages/DataIntelligenceStudio.tsx`.
- Deployed green images tagged `1a6c3e7`.

## Verification
- Backend focused tests: 3 passed.
- Studio ESLint: passed.
- Frontend production build: passed.
- Green backend, worker, main frontend, and institution frontend are running `1a6c3e7`.
- nginx configuration test: successful.
- Staging `/studio` route served the `Current Enrollment Only` marker.
- Protected report schema endpoint returned HTTP 401 without credentials.
- Blue remains active at `94bf94e`; no cutover performed.

## Follow-ups / Deferred
- Perform an authenticated staging journey and compare filtered totals against the dashboard Current Enrollment card.
- Consider adding a visible explanation tooltip for users unfamiliar with the duration-based rule.

## References
- `backend/academic/services/student_counts.py`
- `backend/reports/engine.py`
- `backend/reports/tests.py`
- `frontend/src/pages/DataIntelligenceStudio.tsx`
- `Frontend_and_UI/TESC-2026-11-07-admissions-dashboard-nan-institution-filter.md`

---

**Completed By:** Copilot
**Duration:** Same session
