# Academic Institutions N+1 Query Fix

**Date:** 2026-10-07
**Project:** TESC
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The `/api/academic/institutions/` endpoint was suffering from severe N+1 database bottlenecks during list retrieval, executing numerous redundant queries per institution. This caused poor performance when listing multiple institutions. The issue stemmed from the use of `SerializerMethodField`s in the `InstitutionSerializer` and missing `prefetch_related` calls, as well as an unused `prefetch_related('staff_members')`.

## Symptoms
- Listing institutions via `/api/academic/institutions/` was executing 13 queries for just 5 institutions in the test suite.
- Performance deteriorated linearly with the number of institutions due to the N+1 problem.

## Environment Details
- **Server/Host:** Local Docker Development
- **Services Affected:** Django Backend (Academic App)
- **Related Components:** `InstitutionViewSet`, `InstitutionSerializer`
- **Time First Observed:** 2026-10-07

## Investigation Steps

### 1. Initial Diagnosis
Wrote a `InstitutionPerformanceTestCase` to assert the number of queries. The test revealed 13 queries when listing 5 institutions instead of a baseline of ~4 queries.

### 2. Root Cause Analysis
Inspected `InstitutionSerializer` and `InstitutionViewSet`. We found that the serializer used several missing fields or fields that would trigger N+1, such as nested serializations and method fields that require extra queries, and missing prefetches in `get_queryset()`. In addition, there was a redundant `prefetch_related('staff_members')` in the viewset that was not even used by the serializer, resulting in an extra query.

### 3. Key Findings
- `InstitutionViewSet.queryset` included `prefetch_related('staff_members')` which was unused in `InstitutionSerializer`.
- Several count fields (`student_count`, `staff_count`, etc.) were missing optimized annotations.
- Overwritten `get_queryset()` in `InstitutionViewSet` was missing optimizations.

## Root Cause
- Redundant and missing `prefetch_related` usage.
- Missing DB subqueries for `Count` aggregations leading to potential N+1 or unoptimized queries.

## Prevention / Rule
**Guardrail:** Enforce the use of the Service/Selector Clean Architecture pattern and mandate that all nested fields or aggregations use `Subquery` annotations or `prefetch_related` in a dedicated `selectors.py` file, paired with `IntegerField(read_only=True)` in DRF serializers instead of `SerializerMethodField`.

This architectural pattern centralizes query building and guarantees that the correct subqueries and prefetches are always applied, decoupling this logic from the DRF Views and Serializers.

## Solution

### Immediate Fix
- Updated `InstitutionSerializer` to define integer read-only fields for aggregations (e.g., `staff_count`, `student_count`).
- Created `InstitutionSelector.get_institutions()` to encapsulate `Subquery` counts for students, staff, users, programs, and other statuses, and properly prefetch `facilities`.
- Updated `InstitutionViewSet.get_queryset` to use `InstitutionSelector` and removed the unused `staff_members` prefetch.
- Fixed a testing cache issue by adding `cache.clear()` in the `setUp()` method of the performance test.

### Long-term Fix
Adopt the Clean Architecture pattern (Services & Selectors) across the rest of the backend modules.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- Links to related N+1 fixes in Faculties and Users apps.

## References
- Django `Subquery` documentation.
- Django Rest Framework testing strategies.

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
