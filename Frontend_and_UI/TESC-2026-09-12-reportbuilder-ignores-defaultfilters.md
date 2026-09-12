# ReportBuilder Component Ignores defaultFilters Prop

**Date:** 2026-09-12
**Project:** TESC
**Environment:** Development / Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The `ReportBuilder.tsx` component accepted a `defaultFilters` prop but completely ignored it in its implementation. As a result, when users clicked "Generate Report" on pages with active data filters (like the Students page), the report builder opened with a blank slate instead of preserving the page's current filters.

## Symptoms
- Navigating to the Students Records page, applying filters (e.g., specific institution, gender), and clicking "Generate Report" resulted in a report builder modal with no filters pre-selected.

## Environment Details
- **Services Affected:** `frontend` (`ReportBuilder.tsx`)
- **Related Components:** `Students.tsx`

## Investigation Steps

### 1. Initial Diagnosis
Reviewed `Students.tsx` to see how it triggered the report builder modal.

### 2. Root Cause Analysis
- Analyzed `frontend/src/components/reports/ReportBuilder.tsx`.
- Discovered that although `defaultFilters` was defined in `ReportBuilderProps`, it was never passed to `setFilters()` inside the initialization `useEffect`.

### 3. Key Findings
- `ReportBuilder.tsx` lacked the logic to apply `defaultFilters` on load.
- `Students.tsx` was not passing its active `queryFilters` into the `defaultFilters` prop.
- The `queryFilters` state keys differed from the `ReportBuilder` schema keys (e.g., `institution_id` vs `institution_name`), requiring explicit mapping.

## Root Cause
Unimplemented prop handler in the `ReportBuilder` component and a missing data handoff from the `Students` page.

## Prevention / Rule
**Guardrail:** A TypeScript prop-usage lint rule (or a component-level test) that fails if a component declares a prop in its `Props` interface but never references it in the component body.

`defaultFilters` was declared, typed, and passed by the caller — every signal a normal type-check would treat as "used" — while the actual `useEffect` that should have consumed it never referenced it. A check that greps each declared prop name against the component body (not just against the interface) would have caught the dead prop immediately instead of only surfacing on manual QA.

## Solution

### Immediate Fix
- Updated `ReportBuilder.tsx` to properly set `filters` from `defaultFilters` when the dialog opens.
- Updated `Students.tsx` to map its local filter state (`queryFilters`) into the schema expected by `ReportBuilder` (e.g. mapping `search` to `student_id`, `institution_id` to `institution_name`).

### Long-term Fix
Future reporting integrations on other pages should follow the mapping pattern established in `Students.tsx`.

## Prevention
- [ ] Code changes required: Fixed.

---

**Resolved By:** Antigravity
**Time to Resolution:** 15 minutes
