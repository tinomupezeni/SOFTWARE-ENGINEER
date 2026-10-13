# Replace "Generate Report" dialog with direct Download PDF on all remaining pages

**Date:** 2026-10-13
**Project:** TESC
**Type:** Feature Enhancement / UI Consistency
**Status:** Completed

## Summary
Continuing the pattern established for STEM Students earlier this session,
replaced the "Generate Report" button (which opened a full `ReportBuilder`
filter/columns/options dialog just to produce a PDF) with a direct
Excel/CSV/Download PDF button row on the five remaining pages that still
had it: Specialized Skills Students, Critical Skills Students, Inclusivity,
Possible Graduates, and In-Country Transfers. Two of the five required new
dedicated backend PDF endpoints since their data/scoping isn't expressible
through the generic dynamic-report system at all.

## Context / Trigger
User pasted the Specialized Skills Students page's "Generate Report" button
and asked for the same Download PDF treatment as STEM, plus "check other
pages for similar issues." A `grep` for `ExportButtons` without
`ReportExportButtons` found exactly five remaining pages in this state.

## Scope
**Included:** SpecializedStudents.tsx, CriticalStudents.tsx,
Inclusivity.tsx, PossibleGraduates.tsx, InCountryTransfers.tsx - their
export buttons, and (as a direct consequence of switching to the
button component that disables on zero records) fixing the same
dead-pagination bug found and fixed for STEM's `stem_students` endpoint
earlier this session, wherever it applied to these five pages' backends.

**Excluded:** No new filter fields were added to any of these five pages
(unlike STEM, where the user separately asked for more filters) - this
pass was scoped strictly to the export-button swap and whatever backend
fixes were necessary to make it safe.

## Method
First classified the five pages by what their "Generate Report" dialog was
actually capable of scoping to, since that determines whether a direct
`dynamicReportsService.generatePDF()` call (reusing the generic
dynamic-report system) is correct, or whether a dedicated backend endpoint
is needed instead:

- **Specialized/Critical/Inclusivity**: all use `ReportBuilder reportType=
  "students"` with a `defaultFilters` key (`has_specialized_skills`,
  `has_critical_skills`, `inclusivity`) that's already a custom filter
  handled by `build_queryset`'s dedicated students/graduates custom-filter
  block (confirmed by reading that block directly, not assumed) - a direct
  swap to `generatePDF` with the same filter key preserves identical
  scoping.
- **Possible Graduates**: its dialog had no `defaultFilters` at all. Traced
  its actual scoping logic in the `possible_graduates` backend action
  (`status='Active'`, excludes students who already have a
  `graduation_year`, annotates `expected_graduation_year = enrollment_year
  + program__duration`) - none of this has a corresponding custom filter
  key in `build_queryset`, so the generic system literally cannot express
  it.
- **In-Country Transfers**: its dialog also had no `defaultFilters`, and
  its backend action queries `InCountryTransfer`, a model with no
  relationship to the dynamic-report system's `academic.Student`-centric
  schemas - the same architecture mismatch as the ISEOP PDF bug fixed
  earlier this session.

For the two needing dedicated endpoints, followed the exact precedent set
by ISEOP's `download_pdf` action: query the real data source directly,
build `{data, total, columns}` for the shared `ProfessionalPDFGenerator`,
and return a PDF response - rather than trying to force either concept
into the generic system.

Before wiring any of these five pages to `ReportExportButtons` (which
disables all three buttons when `totalRecords === 0`), re-checked their
backend pagination, since that's exactly the gap that caused STEM's
buttons to be permanently disabled earlier this session. Found
`specialized_students`/`critical_students`/`possible_graduates` all shared
the identical dead-pagination shape (`self.paginate_queryset()` always
returning `None`, no `DEFAULT_PAGINATION_CLASS` anywhere in the project) -
fixed all three before switching their pages over, rather than after a
second round of user reports.

## Decisions & Findings
- Extracted the STEM pagination fix into a shared `paginate_manually()`
  helper (`backend/academic/app_views/student_views.py`) instead of
  duplicating the same `Paginator` logic across four actions - `stem_
  students` was refactored to use it too, for consistency.
- `possible_graduates_download_pdf`'s unfiltered test run took long enough
  to exceed a 120-second test timeout and produced a 4.2MB PDF - the exact
  "unfiltered large PDF" failure mode the main dynamic-report PDF path
  already guards against (`max_rows` cap, documented in an earlier TESC
  dev log entry on 2026-10-13). Added the same 2000-row cap and
  `X-Report-Truncated` response header convention to both new dedicated
  endpoints (also applied defensively to In-Country Transfers, even though
  its current dataset is tiny (22 rows) and unlikely to need it soon).
- Did not touch `inclusivity_report`'s backend action, since it never
  attempted pagination in the first place (frontend fetches everything in
  one request, filters client-side) - no dead-pagination bug there to fix.

## Changes Made
- `backend/academic/app_views/student_views.py`: added shared
  `paginate_manually()` helper; refactored `stem_students` to use it;
  applied it to `specialized_students`/`critical_students`/
  `possible_graduates`; added two new actions,
  `possible_graduates_download_pdf` (url path
  `possible-graduates/download_pdf`) and
  `in_country_transfers_download_pdf` (url path
  `in-country-transfers/download_pdf`), both with a 2000-row cap and
  truncation header.
- `frontend/src/services/reports.services.ts`: added
  `downloadPossibleGraduatesPdf` and `downloadInCountryTransfersPdf`.
- `frontend/src/pages/SpecializedStudents.tsx`,
  `CriticalStudents.tsx`, `Inclusivity.tsx`: swapped `ExportButtons`/
  `ReportBuilder` for `ReportExportButtons` with a direct
  `dynamicReportsService.generatePDF` call using the pages' existing
  custom filter key.
- `frontend/src/pages/PossibleGraduates.tsx`,
  `InCountryTransfers.tsx`: swapped to `ReportExportButtons` calling the
  two new dedicated service functions.
- Commit: `cad060e` on `staging`.

## Verification
- `npx tsc --noEmit -p tsconfig.app.json` and `npm run build` clean for
  all changed files (using the correct tsconfig after the Graduates.tsx
  crash earlier this session revealed `tsc -p .` was a no-op).
- Verified every endpoint via `APIRequestFactory` + `force_authenticate`
  on staging with each page's exact PDF payload:
  - Specialized/Critical/Inclusivity PDFs (via the generic dynamic-report
    system) -> 200, with the debug log confirming each custom filter key
    resolved correctly.
  - `possible_graduates_download_pdf` unfiltered -> originally hung past a
    120s timeout producing 4.2MB; after the row cap, 200 in 4.3 seconds at
    353KB with `X-Report-Truncated: true` set.
  - `in_country_transfers_download_pdf` filtered and unfiltered -> 200.
  - `stem_students`/`specialized_students`/`critical_students` all confirmed
    returning a real `count` and properly sliced `results` after the
    pagination fix.
- Deployed to staging (`backend`, `celery_worker`, `frontend_client`
  rebuilt and recreated); both portal domains and the API verified
  reachable post-deploy (`nginx -s reload` run proactively).

## Follow-ups / Deferred
- No remaining pages use the `ExportButtons`+`ReportBuilder` "Generate
  Report" dialog pattern as of this change - a future `grep -rln
  "ExportButtons\b" frontend/src/pages/*.tsx | xargs grep -L
  "ReportExportButtons"` should return nothing.
- Neither PossibleGraduates nor InCountryTransfers got the richer filter
  treatment STEM received (Status/Program/Enrollment Year) - not asked for
  in this pass; a follow-up if requested.

## References
- [[TESC-2026-10-13-stem-download-pdf-and-staff-stem-filter-expansion]] —
  the STEM Students precedent this rollout follows.
- [[TESC-2026-10-13-stem-students-pagination-dead-code]] — the pagination
  bug class extended here to `specialized_students`/`critical_students`/
  `possible_graduates`.
- [[TESC-2026-10-13-iseop-pdf-zero-records-wrong-data-model]] — the
  dedicated-PDF-endpoint precedent `possible_graduates_download_pdf`/
  `in_country_transfers_download_pdf` follow.
- `frontend/src/components/reports/ReportExportButtons.tsx`,
  `frontend/src/components/ExportButtons.tsx`,
  `frontend/src/components/reports/ReportBuilder.tsx`

---

**Completed By:** tinomupezeni (with Claude Sonnet 5)
**Duration:** ~1.5 hours
