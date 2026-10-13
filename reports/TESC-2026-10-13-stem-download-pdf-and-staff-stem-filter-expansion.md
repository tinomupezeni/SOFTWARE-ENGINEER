# STEM Students: replace Generate Report dialog with Download PDF; expand Staff/STEM filters

**Date:** 2026-10-13
**Project:** TESC
**Type:** Feature Enhancement / UI Consistency
**Status:** Completed

## Summary
STEM Students was the only page in the dynamic-report system still using a
"Generate Report" button that opened a full filter/columns/options dialog
(`ReportBuilder`) just to produce a PDF, inconsistent with every other page
(Staff, Students, Graduates, ISEOP), which download directly from a single
button. Replaced it with the same direct Download PDF pattern, and added
more filter fields to both the Staff and STEM Students pages at the user's
request, matching the richer filter set on the main Students page.

## Context / Trigger
User pasted the STEM page's "Generate Report" dialog (Filters/Columns/
Options tabs, 15 selectable columns) next to the header's simple
"Excel / CSV / Generate Report" buttons, and asked to remove the dialog in
favor of a direct Download PDF button like Staff has, plus add more dynamic
filter options to both Staff and STEM Students, matching Students.

## Scope
**Included:**
- STEM Students (`frontend/src/pages/StemStudents.tsx`): swap
  `ExportButtons` (Excel/CSV/Generate Report, opens `ReportBuilder` dialog)
  for `ReportExportButtons` (Excel/CSV/Download PDF, direct).
- Staff and STEM Students filter bars: add fields confirmed with the user
  (Staff: Gender, Department, Qualification; STEM: Status, Program,
  Enrollment Year).

**Explicitly excluded:**
- The three sibling pages that also use `ReportBuilder` with a similar
  `defaultFilters` pattern (`CriticalStudents.tsx`, `Inclusivity.tsx`,
  `SpecializedStudents.tsx`) were not touched - the user's request named
  Staff and STEM Students specifically, and those three use a different,
  already-correctly-handled custom filter key
  (`has_critical_skills`/`inclusivity`/`has_specialized_skills`, handled by
  `build_queryset`'s dedicated students/graduates custom-filter block) -
  changing them wasn't asked for and is a separate scope decision.
- No changes to `ReportBuilder.tsx` itself, which remains in use by those
  three pages plus any future schema-driven report type.

## Method
Before touching the STEM page, verified what its existing `defaultFilters={{
program__category: 'STEM' }}` actually did server-side, since replacing the
delivery mechanism (dialog vs. direct button) needed to preserve the exact
same scoping. Traced `program__category` through `build_queryset`
(`backend/reports/dynamic_service.py`) and found it's one of the
custom-filter block's special-cased keys (alongside
`has_specialized_skills`/`has_critical_skills`/`inclusivity`), applied via
an explicit `Q()` filter - not a declared schema field, so it never collides
with the generic per-field filter loop. This confirmed the new direct
Download PDF handler just needed to send the same `program__category: 'STEM'`
filter key to behave identically to the old dialog.

For Staff's new filters, checked whether the page does server-side or
client-side filtering (`useStaff()` fetches the full unpaginated staff list,
filtering happens entirely in a `useMemo` over the loaded array) - so adding
Gender/Department/Qualification needed no new backend query params, only
new `Select` controls and filter-predicate branches, matching the existing
Institution/Position pattern exactly. For the Download PDF side, the
`'staff'` schema (`schema_config.py`) only declared `employee_id`,
`full_name`, `position` before this session's earlier fixes added
`institution_name`/`department_name`/`is_active` - `gender` and
`qualification` still needed declaring so they're usable as PDF filters,
not just client-side table filters.

For STEM's new filters, the on-page table/stats come from a dedicated
backend endpoint (`stem_students` in
`backend/academic/app_views/student_views.py`), which only accepted
`institution_id`/`search`/`gender` - extending it to accept
`status`/`program_id`/`enrollment_year` was necessary since (unlike Staff)
this endpoint is paginated server-side, so client-side-only filtering over
"whatever's loaded" wasn't an option.

## Decisions & Findings
- STEM's Program filter dropdown is populated from `getAllPrograms()`
  filtered client-side to `categories.includes('STEM') || category ===
  'STEM'`, rather than adding a new backend endpoint - reuses an existing
  generic endpoint, avoids over-building for what's a small, mostly-static
  list.
- STEM's Status filter options are hardcoded to the known `Student.status`
  choices (`Active`/`Attachment`/`Graduated`/`Suspended`/`Deferred`/
  `Dropout`) rather than fetched from a filter-options endpoint, since no
  such endpoint exists for this page and the full Student model's status
  choices are a small, stable, hardcoded set already duplicated elsewhere
  in the codebase (e.g. the `Student` TypeScript interface's status union).
- Confirmed via the audit from earlier in this session that `ReportBuilder`
  itself (used by the three untouched sibling pages) is schema-driven and
  therefore immune to the "hardcoded PDF columns drift from schema" bug
  class - no action needed there.

## Changes Made
- `frontend/src/pages/StemStudents.tsx`: removed `ReportBuilder`/
  `ExportButtons`/`reportBuilderOpen`; added `ReportExportButtons` with a
  `handleDownloadPdf` calling `dynamicReportsService.generatePDF` directly;
  added Status/Program/Enrollment Year filter state, UI, and fetch-param
  wiring.
- `frontend/src/pages/Staff.tsx`: added Gender/Department/Qualification
  filter state, `filterOptions` derivation, filter-predicate logic, and PDF
  filter mapping.
- `backend/reports/schema_config.py`: added `gender` and `qualification`
  field declarations to the `'staff'` schema entry.
- `backend/academic/app_views/student_views.py`: extended `stem_students`
  to accept `status`/`program_id`/`enrollment_year` query params.
- `frontend/src/services/reports.services.ts`: added `status`/`program_id`/
  `enrollment_year` to the shared `StudentReportFilters` interface and
  `buildReportParams`.
- Commit: `97e4a2c` on `staging`.

## Verification
- `npx tsc --noEmit` and `npm run build` clean for all changed frontend
  files.
- `python3 -m py_compile` clean for all changed backend files.
- Verified via `APIRequestFactory` + `force_authenticate` on staging:
  - `stem_students` with `status`+`enrollment_year` filters -> 200.
  - Staff PDF with `gender`+`qualification` filters -> 200.
  - STEM PDF with its `program__category`+`status` filters -> 200, and the
    debug log confirmed `program__category` is applied via the custom-filter
    block (not dropped), matching the old dialog's behavior.
- Deployed to staging (`backend`, `celery_worker`, `frontend_client`
  rebuilt and recreated); both portal domains and the API verified
  reachable post-deploy (`nginx -s reload` run proactively per the
  self-heal gap found earlier this session).

## Follow-ups / Deferred
- `CriticalStudents.tsx`, `Inclusivity.tsx`, `SpecializedStudents.tsx` still
  use the `ReportBuilder` dialog pattern - if the user wants the same
  Download PDF consistency applied there, that's a follow-up request, not
  assumed by this change.
- No filter-options backend endpoint exists for STEM Students (Status
  options are hardcoded); if the status choice set ever changes, this page
  (and the `Student` TypeScript interface, and other hardcoded occurrences)
  would need updating in lockstep.

## References
- [[TESC-2026-10-13-pdf-400-missing-schema-fields-and-institution-filter-mismatch]]
  — the `'staff'` schema field-declaration gap this builds on.
- `frontend/src/components/reports/ReportBuilder.tsx`,
  `frontend/src/components/ExportButtons.tsx`,
  `frontend/src/components/reports/ReportExportButtons.tsx`

---

**Completed By:** tinomupezeni (with Claude Sonnet 5)
**Duration:** ~1 hour
