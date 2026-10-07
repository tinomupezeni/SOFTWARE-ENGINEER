# Academic Students N+1 Query Fix

**Date:** 2026-10-07
**Project:** TESC
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The `/api/academic/students/` endpoint was suffering from a massive N+1 database bottleneck during list retrieval. For every student returned, the API would make additional queries to fetch their `faculty`, `department`, `inclusivity_profile`, `work_for_fees_profile`, and `iseop_profile`, causing severe latency as the number of students grew.

## Symptoms
- Performance deteriorated linearly with the number of students due to the N+1 problem.
- When listing students via `/api/academic/students/`, each row serialized generated multiple database requests to related models and tables.

## Environment Details
- **Server/Host:** Local Docker Development
- **Services Affected:** Django Backend (Academic App)
- **Related Components:** `StudentViewSet`, `StudentSerializer`
- **Time First Observed:** 2026-10-07

## Investigation Steps

### 1. Initial Diagnosis
Wrote `StudentPerformanceTestCase` to assert the number of queries for listing students. Without optimization, the number of queries scaled with the number of students (e.g. 13+ queries for 5 students, and linearly more as students are added).

### 2. Root Cause Analysis
Inspected `StudentSerializer.to_representation()` and its fields. We found that the serializer accessed `instance.inclusivity_profile`, `instance.work_for_fees_profile`, and `instance.iseop_profile` within a `try/except` block, triggering implicit reverse relation queries. Furthermore, fields like `faculty_name` and `department_name` were read using dot notation (e.g., `source='faculty.name'`). 

### 3. Key Findings
- `StudentViewSet.get_queryset()` used `select_related('institution', 'program')` but missed many other related models.
- Missing `select_related` for `faculty`, `department`, `inclusivity_profile`, `work_for_fees_profile`, and `iseop_profile`.

## Root Cause
- Missing `select_related` statements in the viewset's base queryset for relations explicitly accessed in the serializer.

## Prevention / Rule
**Guardrail:** Enforce the use of the Service/Selector Clean Architecture pattern and mandate that all nested fields or aggregations use `Subquery` annotations, `select_related`, or `prefetch_related` in a dedicated `selectors.py` file or `get_queryset()` override. 

When overriding `to_representation` in a serializer or using `source='relation.field'`, developers MUST verify that the related models are joined via `select_related`/`prefetch_related` on the queryset. 

## Solution

### Immediate Fix
- Updated `StudentViewSet.get_queryset` to include `faculty`, `department`, `inclusivity_profile`, `work_for_fees_profile`, and `iseop_profile` in the `select_related` call.
- Validated via `assertNumQueries(8)` that the number of queries is now bounded (O(1) with respect to the number of students), executing exactly 8 queries (2 session, 5 pagination/stats counts, 1 large data query) regardless of pagination size.

### Long-term Fix
Adopt the Clean Architecture pattern (Services & Selectors) across the rest of the backend modules, shifting query building to `selectors.py`.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Links to related N+1 fixes in Faculties, Users, and Institutions views.

## References
- Django `select_related` and `prefetch_related` documentation.
- Django Rest Framework N+1 prevention strategies.

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
