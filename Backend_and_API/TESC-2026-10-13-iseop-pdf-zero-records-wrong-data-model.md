# ISEOP Download PDF always returned 0 records despite the page showing 38

**Date:** 2026-10-13
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The ISEOP page displayed 38 student records and Excel/CSV export worked
correctly, but Download PDF always produced a PDF with 0 rows. The cause
was architectural, not a filter typo (unlike the earlier
[[TESC-2026-10-13-dynamic-report-filter-fielderror-500s]] fix from the same
session): ISEOP students live in their own standalone `iseop.IseopStudent`
table and are never synced into `academic.Student`, but the Download PDF
button called the academic dynamic-report system, which only ever queries
`academic.Student`.

## Symptoms
- ISEOP page showed "Students (38)" and a full table of records.
- Excel and CSV export (client-side, built from the same loaded data)
  worked fine.
- Download PDF produced a PDF file with an empty data table every time.
- The page also rendered two identical `Excel / CSV / Download PDF` button
  groups (one in the page header, one in the student-table card header) -
  flagged by the user as redundant alongside the bug report.

## Environment Details
- **Server/Host:** tesc-staging VM, `tesc-backend-1` container
- **Services Affected:** `backend/iseop/views.py`,
  `frontend/src/pages/ISEOP.tsx`, `frontend/src/services/iseop.services.ts`
- **Related Components:** the academic dynamic-report system
  (`backend/reports/dynamic_service.py`, `schema_config.py`) that the PDF
  button incorrectly routed through
- **Time First Observed:** 2026-10-13, reported by the user alongside a
  request to check for similar issues and remove the duplicate buttons.

## Investigation Steps

### 1. Initial Diagnosis
Confirmed via `manage.py shell` that `iseop.IseopStudent.objects.count()`
returned 38 (matching the page), while the PDF button's actual backend call
(`report_type: 'students', filters: {is_iseop: true}`) queries
`academic.Student.objects.filter(iseop_profile__isnull=False)`.

### 2. Root Cause Analysis
Checked for overlap between the two tables directly:

```python
from iseop.models import IseopStudent
from academic.models import Student
ids = list(IseopStudent.objects.values_list('student_id', flat=True))
Student.objects.filter(student_id__in=ids).count()
# -> 0
```

Zero of the 38 `IseopStudent` rows have a matching `academic.Student` row at
all - not just a missing `StudentISEOP` profile flag, but no corresponding
row in the table the PDF generator queries, full stop.

Traced how these 38 records were created: `IseopStudentViewSet`'s default
`ModelViewSet.create()` (used by the page's single "Add Student" flow)
writes only to `IseopStudent`; `bulk_upload` (used for CSV/Excel imports)
does create a linked `academic.Student` + `IseopEnrollment`, but neither
path ever sets `academic.StudentISEOP` (the profile the dynamic report's
`is_iseop` filter actually checks) - and these 38 specifically have no
`academic.Student` row either, meaning they went through the single-add
path, not bulk upload.

### 3. Key Findings
- `academic.Student` + `academic.StudentISEOP` is a **different, unrelated
  population** from `iseop.IseopStudent`: confirmed with the user that ISEOP
  students are community members taking short courses (building, woodwork,
  etc.) run by institutions, while `academic.Student` is the 3-4 year
  degree-program population. They are intentionally separate - the fix is
  **not** to sync/merge them, which would conflate two different kinds of
  people.
- The academic dynamic-report system (`report_type='students'`) was simply
  the wrong backend for this page to call for PDF export in the first
  place, since it only ever reads `academic.Student`.
- Excel/CSV worked because they're built entirely client-side from the
  `IseopStudent` data already loaded for the table - they never touched the
  dynamic-report system at all. Download PDF was the only export path wired
  to the wrong data source.
- Checked other pages using `report_type: 'students'` for PDF (Graduates.tsx)
  - that one is legitimate, since Graduated students genuinely are
  `academic.Student` rows filtered by `status='Graduated'`, the same
  population. ISEOP was the one case of a page whose displayed data and its
  PDF-export data source were two disjoint tables.
- The duplicate `ReportExportButtons` block was specific to this page; the
  three other pages built on the same shared component (Students, Graduates,
  Staff) each render exactly one instance.

## Root Cause
The ISEOP page's Download PDF button called the academic dynamic-report
system (`report_type: 'students'`), which exclusively queries
`academic.Student`. ISEOP students are intentionally stored in a separate
`iseop.IseopStudent` table for a different population (community
short-course learners vs. degree students) and are never present in
`academic.Student`, so the PDF query matched zero rows regardless of how
many ISEOP students existed.

## Prevention / Rule
**Guardrail:** any new "Download PDF" button must be code-reviewed against
the question "does this call the same backend table/queryset the page's
list view and its Excel/CSV export already use?" - if a page's primary data
source is a model outside `REPORT_SCHEMAS` / the academic dynamic-report
system (as `iseop.IseopStudent` is), its PDF export must be wired to a
dedicated endpoint querying that same model, not the generic dynamic-report
system, no matter how convenient the shared button component makes it to
wire up.

This closes the gap because the actual defect was a page calling the wrong
backend for a data model it was never designed to serve - a type/model
check at review time (or a lightweight automated check that every page's
three export handlers target the same underlying model) catches this
before it ships, where a runtime test wouldn't necessarily surface it since
the PDF request succeeds (200) and merely returns an empty table.

## Solution

### Immediate Fix
Added a dedicated `download_pdf` action directly on `IseopStudentViewSet`
(`backend/iseop/views.py`) that queries `IseopStudent` with the same
filters already applied client-side for Excel/CSV, and renders the PDF via
the existing generic `reports/pdf_generator.py` (`generate_dynamic_report_pdf`,
which only needs a plain `{data, total, columns}` dict - no dependency on
the `REPORT_SCHEMAS`/dynamic-report machinery). Updated
`frontend/src/services/iseop.services.ts` and
`frontend/src/pages/ISEOP.tsx`'s `handleGenerateReport` to call this new
endpoint instead of `dynamicReportsService.generatePDF`.

Also removed the duplicate `ReportExportButtons` instance from the
student-table card header, keeping only the one in the page header (matches
the Students/Graduates/Staff pages' pattern).

```bash
# Verified via APIRequestFactory + force_authenticate through the real
# download_pdf action, unfiltered and with a real status filter:
# unfiltered -> 200, application/pdf, 8350 bytes (all 38 records)
# filters={'status': 'Active/Enrolled'} -> 200, 8188 bytes (correct subset)
```

### Long-term Fix
If ISEOP students are ever meant to appear in the broader Reports Studio /
dynamic-report system (e.g. for cross-population reporting), that would
need a deliberate, explicit decision on how the two populations relate -
not an implicit sync. No such requirement exists today, so no further
action is planned.

## Prevention
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — none specific; general 200-with-empty-data
      responses are hard to alert on generically.
- [ ] Documentation to update — none.
- [x] Code changes required — done (see Solution).

## Related Issues
- [[TESC-2026-10-13-dynamic-report-filter-fielderror-500s]] — same session,
  same page, different bug: that one was the earlier FieldError crash on
  this same button before this data-model mismatch was found underneath it.

## References
- `backend/iseop/views.py`
- `backend/iseop/models.py` (`IseopStudent`, `IseopEnrollment`)
- `backend/academic/models.py` (`StudentISEOP`)
- `backend/reports/pdf_generator.py`
- Commit: `f06bc74` on `staging`.

---

**Resolved By:** tinomupezeni (with Claude Sonnet 5)
**Time to Resolution:** ~45 minutes
