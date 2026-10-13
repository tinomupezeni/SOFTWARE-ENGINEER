# PDF reports: overlapping table cells, missing gender metrics, blank cells for missing data

**Date:** 2026-10-13
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
Every "Download PDF" feature in the system shares one generator
(`backend/reports/pdf_generator.py`). The user reported three rendering
problems affecting all of them: table cells with long text visually
overlapped the row below instead of wrapping, the gender-ratio metrics
section was missing or showed incorrect "0%" ratios on some report types,
and missing/blank field values rendered as empty space indistinguishable
from a bug. Fixed once in the shared generator so every PDF across the
system (Students, Graduates, Staff, ReportBuilder-driven reports,
scholarships/mobility/placements, Reports Studio, and the ISEOP export
added earlier this session) picks up the fix.

## Symptoms
- Long cell values (e.g. a full student name or a long institution name)
  overflowed their row's fixed height and overlapped the text of the row
  below it.
- Blank/`None` field values rendered as empty cells.
- Gender ratio ("Male Students X, Ratio Y%") either didn't appear at all,
  or appeared with the correct counts but a hardcoded "0%" ratio.

## Environment Details
- **Server/Host:** tesc-staging VM, `tesc-backend-1` container
- **Services Affected:** `backend/reports/pdf_generator.py` (shared by
  every PDF-producing endpoint), `backend/reports/dynamic_views.py`,
  `backend/reports/api.py` (Reports Studio), `backend/reports/tasks.py`,
  `backend/iseop/views.py`
- **Time First Observed:** 2026-10-13, reported by the user as a
  cross-cutting PDF quality issue.

## Investigation Steps

### 1. Initial Diagnosis
Read `ProfessionalPDFGenerator._create_data_table()`: table cells were
built from plain Python strings (`row.append(str_value)`), not ReportLab
`Paragraph` flowables. A `platypus.Table` only wraps and grows row height
for content it can measure and reflow (Paragraphs); plain strings placed
directly don't get that treatment reliably at small row heights, producing
the overlap.

### 2. Root Cause Analysis
Checked every PDF-producing caller of `report_data` for how `metrics` gets
built: `DynamicReportService.generate_report_data()`
(`backend/reports/dynamic_service.py`) correctly computes
`male_count`/`female_count`/`male_pct`/`female_pct`, but the Reports Studio
PDF path (`backend/reports/api.py`) only ever set
`{"male_count": ..., "female_count": ...}` with no percentage keys - so
`_create_summary_stats()`'s `metrics.get('male_pct', 0)` silently fell back
to `0` for every Reports Studio PDF. Separately, the gender block's
visibility check (`metrics.get('male_count') or metrics.get('female_count')`)
hid the whole section whenever both counts were legitimately zero.

### 3. Key Findings
- Only one shared generator exists, so a fix here reaches every PDF export
  in the system - confirmed by `grep`ing all callers of
  `generate_dynamic_report_pdf`/`ProfessionalPDFGenerator`:
  `dynamic_views.py`, `tasks.py`, `api.py` (Reports Studio), `iseop/views.py`.
- `iseop/views.py`'s `download_pdf` action (added earlier this session)
  built its `report_data` with no `metrics` key at all, so ISEOP PDFs never
  showed gender data - another instance of the same "every caller must
  remember to compute this" fragility.
- Wrapping cell text in `Paragraph` to fix the overlap introduces a new
  risk: `Paragraph` parses its text as a small XML-like markup, so
  unescaped `&`, `<`, `>` in real data (an institution name like
  "Harare Polytechnic & College", a quoted program name) would raise a
  parse error and fail PDF generation entirely - this wasn't a problem
  before since only a few static/controlled strings (title, institution
  name) went through `Paragraph`; after the fix, every data cell does.

## Root Cause
Three independent gaps in the shared PDF generator:
1. Table cells were plain strings instead of `Paragraph` flowables, so long
   content didn't reflow/wrap - it overlapped the next row instead.
2. Percentage computation for gender ratios was left to each caller instead
   of being computed once in the generator, so some callers (Reports
   Studio, the new ISEOP endpoint) never passed `male_pct`/`female_pct` (or
   never passed `metrics` at all), rendering as a hardcoded "0%" or missing
   entirely. The visibility check also hid the section on a legitimate 0/0
   gender split.
3. Missing/blank values rendered as nothing, rather than an explicit
   placeholder.

## Prevention / Rule
**Guardrail:** any new field appended to a PDF `report_data` dict that is
user-supplied or DB-sourced text (not a static label) must go through the
shared `_pdf_text()` escape helper before being passed to `Paragraph` -
code review for any change to `pdf_generator.py` or a new PDF-producing
endpoint should check for a raw (unescaped) `Paragraph(some_variable, ...)`
call. Similarly, any new report type's metrics should rely on the
generator's own percentage derivation (already computed once from
`male_count`/`female_count`/`total` if not supplied) rather than
recomputing it per-caller, so a future report type can't reintroduce the
same "forgot to compute the percentage" gap.

This closes the gap because the single shared generator is the only choke
point every PDF export passes through; centralizing both the escaping and
the percentage derivation there means no future caller can reintroduce
either bug by omission.

## Solution

### Immediate Fix
In `backend/reports/pdf_generator.py`:
- `_create_data_table()` now wraps every header/body cell in a `Paragraph`
  (via new `_pdf_text()`-escaped values), letting `platypus.Table` size row
  height to the wrapped content instead of overlapping.
- Missing/blank values (`None` or `''`) now render as `"-"`.
- Added `_pdf_text()` - a shared `xml.sax.saxutils.escape` wrapper - applied
  everywhere dynamic text reaches a `Paragraph`: cell values, column
  labels, the institution-name sub-header, the title, and group labels.
- `_create_summary_stats()` now derives `male_pct`/`female_pct` itself from
  `male_count`/`female_count`/`total` whenever a caller didn't supply them,
  and shows the gender block whenever those count keys are present at all
  (not only when truthy).
- `backend/iseop/views.py`'s `download_pdf` now computes and passes
  `male_count`/`female_count` so ISEOP PDFs get the same gender block.
- Renamed the PDF header from "CENTRAL DATA SYSTEM" to "SCALAREYE DATA
  SYSTEM" per a follow-up request in the same session.

```bash
# Verified by generating a PDF with deliberately adversarial data: an
# institution name containing "&" and "<Advanced>", blank gender/program/
# institution fields, and a name long enough to require 4 wrapped lines -
# inspected the rendered PDF directly and confirmed: no crash, correct
# multi-line wrapping with no overlap, "-" for every blank field, and
# correct 50.0%/0.0% gender ratios.
```

### Long-term Fix
None needed beyond the guardrail above - the fix is centralized in the one
shared generator all PDF features already use.

## Prevention
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — none specific.
- [ ] Documentation to update — none.
- [x] Code changes required — done (see Solution).

## Related Issues
- [[TESC-2026-10-13-iseop-pdf-zero-records-wrong-data-model]] — the ISEOP
  `download_pdf` endpoint this fix also updated was added during that
  earlier fix in the same session.

## References
- `backend/reports/pdf_generator.py`
- `backend/reports/api.py` (Reports Studio PDF path)
- `backend/iseop/views.py`
- Commit: `f6586a8` on `staging`.

---

**Resolved By:** tinomupezeni (with Claude Sonnet 5)
**Time to Resolution:** ~40 minutes
