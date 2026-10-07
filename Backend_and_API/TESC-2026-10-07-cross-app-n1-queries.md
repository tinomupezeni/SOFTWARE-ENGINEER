# Cross-App N+1 Database Query Fixes

**Date:** 2026-10-07
**Project:** TESC
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
While auditing the codebase to enforce the Clean Architecture Service/Selector pattern and prevent N+1 queries, several bottlenecks were identified across multiple apps (`staff`, `innovation`, `instauth`, and `analysis`). These endpoints were executing numerous redundant database queries, causing performance degradation that scaled linearly with data size. 

## Symptoms
- Listing records via various API endpoints or dashboards generated an unpredictable and non-constant number of queries.
- Dashboard analysis endpoints (`student_teacher_ratio`) executed two additional queries per institution.

## Environment Details
- **Server/Host:** Local Docker Development
- **Services Affected:** `staff` (VacancyViewSet), `innovation` (ProjectViewSet), `instauth` (InstitutionUserViewSet), `analysis` (student_teacher_ratio)
- **Time First Observed:** 2026-10-07

## Investigation Steps

### 1. Initial Diagnosis
Audited DRF Serializers and ViewSets for `SerializerMethodField`, explicit dot-notation source paths (e.g. `source='relation.name'`), and nested object serializers across all apps.

### 2. Root Cause Analysis
- **`instauth` (InstitutionUserViewSet):** Fetched users but the serializer accessed `role.name` without `select_related('role')`.
- **`innovation` (ProjectViewSet):** Fetched projects but the serializer accessed `institution.name`, `institution.type`, and nested `ip_details` without the corresponding `select_related` calls.
- **`staff` (VacancyViewSet):** Fetched vacancies but the serializer accessed `faculty.name` and `department.name` without `select_related`.
- **`analysis` (student_teacher_ratio):** Iterated over `Institution.objects.all()` and executed `.count()` for students and staff dynamically within a python `for` loop.

## Root Cause
- Missing `select_related` statements in the viewset's base querysets.
- Performing dynamic database aggregations inside Python loops instead of pushing the computation to the database using `.annotate()`.

## Prevention / Rule
**Guardrail:** Enforce the use of the Service/Selector Clean Architecture pattern. All viewsets must define required DB joins using `select_related` or `prefetch_related`. Dashboard analysis APIs must leverage Django's `annotate(Count(..., distinct=True))` instead of doing queries in loops.

## Solution

### Immediate Fix
- **`instauth`**: Updated `InstitutionUserViewSet.get_queryset` to use `.select_related('role')`.
- **`innovation`**: Updated `ProjectViewSet.queryset` to include `select_related('hub', 'institution', 'ip_details')`.
- **`staff`**: Updated `VacancyViewSet.get_queryset` to include `select_related('institution', 'faculty', 'department')`.
- **`analysis`**: Refactored `student_teacher_ratio` to use `.annotate(total_students=Count('students'), total_teachers=Count('staff_members', filter=...))` avoiding the loop queries entirely.

### Long-term Fix
Continuing to adopt Clean Architecture across all new development.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

---

**Resolved By:** Antigravity
**Time to Resolution:** 15 minutes
