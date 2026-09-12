# ReportBuilder Bypassed on Students Page for Direct Download

**Date:** 2026-09-12
**Project:** TESC
**Environment:** Development / Staging
**Severity:** Low
**Status:** Resolved

## Summary
The "Generate Report" button on the Students page previously opened the `ReportBuilder` modal. However, since the page already features an extensive "Advanced Data Filters" section, opening a second modal with duplicate filter inputs was an unnecessary friction point and a design flaw. The button has been refactored to directly generate and download the PDF using the existing page filters.

## Symptoms
- Users had to click "Generate Report", wait for a modal to open, and potentially re-verify filters before clicking a second "Generate" button.

## Environment Details
- **Services Affected:** `frontend`
- **Related Components:** `Students.tsx`

## Investigation Steps
### 1. Root Cause Analysis
- The UI workflow required two steps to generate a report, when one would suffice given the page's existing filter state.
- `Students.tsx` used `setReportBuilderOpen(true)` instead of directly triggering a report generation API call.

### 2. Key Findings
- The `dynamicReportsService.generatePDF` function could be called directly with the mapped `queryFilters`.

## Root Cause
A design flaw where the reporting component (`ReportBuilder`) duplicated the filtering capabilities already present on the host page.

## Prevention / Rule
**Guardrail:** A UI-review checklist item for any "Generate Report"/export action: if the host page already exposes filter state the report needs, the button must call the export function directly with that state — a second filter-collecting modal is only justified when the report's filter shape genuinely can't be derived from the page.

This turns "does this page already have the filters I'm about to ask for again?" into a required question at design time, instead of something only caught after users complain about the extra click.

## Solution
### Immediate Fix
- Removed the `<ReportBuilder />` component from `Students.tsx`.
- Replaced the button's `onClick` handler with `handleGenerateReport`, which directly maps the page's `queryFilters` to the report schema and calls `dynamicReportsService.generatePDF`.

### Long-term Fix
When building data-heavy list pages with built-in advanced filters, prefer 1-click direct report generation over popping up a generic report builder modal.

## Prevention
- [ ] Code changes required: Implemented direct download on the Students page.

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
