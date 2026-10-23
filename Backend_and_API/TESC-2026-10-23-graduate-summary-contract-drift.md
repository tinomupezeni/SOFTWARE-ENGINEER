# Student Summary Cards Omitted Graduation Outcomes

**Date:** 2026-10-23
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The institution Student Statistics page showed zero passed and failed
students while the Graduates page correctly showed 14 passed and 2 failed.
The lightweight `/academic/students/all-light/` response used by the summary
cards omitted `graduation_year` and `final_grade`, so the frontend could not
classify graduation outcomes.

## Symptoms
- Graduates page displayed 14 passed and 2 failed records.
- Student Statistics displayed `PASSED 0` and `FAILED 0`.
- Total, active, and graduated counts were otherwise populated.

## Environment Details
- **Server/Host:** `10.50.1.37`
- **Services Affected:** `tesc-backend-1`, institution frontend consumer
- **Related Components:** `StudentViewSet.all_light`, `inst/src/pages/Students.tsx`
- **Time First Observed:** 2026-10-23

## Investigation Steps

### 1. Initial Diagnosis
Compared the two page data paths. The Graduates page uses the graduation
management/statistics endpoints, while Student Statistics fetches
`/academic/students/all-light/` for its complete filtered summary.

### 2. Root Cause Analysis
The lightweight endpoint returned status and enrollment fields but not
`graduation_year` or `final_grade`. The frontend normalization therefore set
both values to `undefined`, making passed and failed predicates return zero.

### 3. Key Findings
- The Graduates endpoint had the correct 14/2 outcome data.
- The Student Statistics endpoint had an incomplete response contract.
- The mismatch was not a database-counting error.

## Root Cause
The backend lightweight response contract drifted from the fields required by
the institution frontend's summary calculations.

## Prevention / Rule
**Guardrail:** Contract tests for lightweight student endpoints must assert every
field consumed by summary calculations, including graduation outcome fields.

This prevents performance-oriented response reductions from silently changing
business metrics.

## Solution

### Immediate Fix
Added `graduation_year` and `final_grade` to `/academic/students/all-light/`.
Updated the dashboard test fixture to create the required `Person` relation and
assert the response contract.

### Long-term Fix
Keep frontend summary fields and backend lightweight serializers covered by a
bidirectional contract test.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## References
- `backend/academic/app_views/student_views.py`
- `inst/src/pages/Students.tsx`
- `inst/src/services/students.services.ts`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
