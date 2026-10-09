# Categorical Filters Rendered as Plain Text Inputs

**Date:** 2026-10-09
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The Data Intelligence Studio filter builder was rendering plain text inputs for all fields, even categorical ones (like Gender, Status, Province). This violated the design consistency of the app (specifically the Students page), which uses standard dropdowns (`<Select>`) for categorical data to ensure valid queries.

## Root Cause
The backend's semantic layer (`get_semantic_schema`) provided the field types (`categorical`) but did not provide the actual distinct `options` for the frontend to render into a dropdown. Without the options, the generic frontend builder fell back to rendering a plain text `<Input>`.

## Solution
- **Backend:** Modified `get_semantic_schema` in `backend/reports/semantic.py` to dynamically query distinct values (`Model.objects.values_list(orm_path).distinct()`) for any field labeled as `categorical`, appending them to the schema payload under the `options` key.
- **Frontend:** Updated `frontend/src/pages/DataIntelligenceStudio.tsx` to conditionally render a Shadcn `<Select>` component containing the `field.options` when `field.type === 'categorical'`, matching the UX of the dedicated Students page.

## Prevention / Rule
**Guardrail:** When building schema-driven UI components, the API contract must include data constraints (like distinct options for enums/categories) so the frontend can render appropriate specific inputs (Dropdowns/Radios) rather than falling back to unconstrained text inputs.

---

**Resolved By:** Antigravity
