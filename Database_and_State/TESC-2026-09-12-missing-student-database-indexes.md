# Missing Database Indexes on Student Model

**Date:** 2026-09-12
**Project:** TESC
**Environment:** Development / Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The `Student` model in the `academic` app was missing database indexes for fields that are frequently used in filtering across the application (like the main Students datatable and reporting). This omission could lead to slow data retrieval and full table scans on large datasets.

## Symptoms
- Potential performance degradation on the "STUDENTS RECORDS" page and during dynamic report generation when applying filters like `status`, `gender`, or `enrollment_year`.

## Environment Details
- **Services Affected:** `backend` (PostgreSQL)
- **Related Components:** `academic/models.py`

## Investigation Steps

### 1. Initial Diagnosis
Reviewed `backend/academic/models.py` after a request to optimize data retrieval speeds on filtered lists.

### 2. Root Cause Analysis
- Checked the `Student` class and found that while ForeignKeys (like `institution` and `program`) receive automatic indexes, other commonly queried scalar fields did not have indexes defined in the model's `Meta` class.

### 3. Key Findings
- Fields heavily used in `queryFilters` (such as `status`, `gender`, `enrollment_year`, `selected_level`, and `selected_category`) lacked explicit `db_index=True` or `Meta.indexes` declarations.

## Root Cause
Failure to define indexes for frequently queried fields in Django models.

## Prevention / Rule
**Guardrail:** A code-review checklist item (or a grep-based pre-commit check) requiring that any model field appearing in a `.filter()`, `.order_by()`, or `queryFilters`-style lookup have a corresponding `db_index=True` or `Meta.indexes` entry added in the same change that introduces the query — reviewed when the query is written, not discovered later via a performance audit.

## Solution

### Immediate Fix
- Added a `Meta` class to the `Student` model containing `models.Index` declarations for `status`, `gender`, `enrollment_year`, `selected_level`, and `selected_category`.
- Generated and applied the migration (`academic.0019_student_academic_st_status_f931b2_idx_and_more`).

### Long-term Fix
Routinely evaluate filtering patterns on core models (like `Student` and `Graduate`) to ensure that heavy query paths are backed by appropriate database indexes.

## Prevention
- [ ] Code changes required: Fixed.

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
