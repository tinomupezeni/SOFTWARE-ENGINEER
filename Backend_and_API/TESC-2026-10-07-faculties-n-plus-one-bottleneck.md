# Faculties N+1 Database Bottleneck Fixed via Clean Architecture

**Date:** 2026-10-07
**Project:** TESC
**Environment:** Staging / Development
**Severity:** High
**Status:** Resolved

## Summary
During load testing with k6 and Grafana, severe database bottlenecks were observed on the `/faculties/faculties/` and `/users/roles/` endpoints. The faculties endpoint generated hundreds of repeated SQL queries (an N+1 problem) due to missing annotations and prefetches, mixed directly into the ViewSet and Serializer layers.

## Symptoms
- The `/faculties/faculties/` endpoint averaged 1.26s response time under a load of 50 Virtual Users.
- 13 database queries were executed just to fetch 5 faculty records with their nested department counts and lists. 

## Environment Details
- **Server/Host:** TESC Staging
- **Services Affected:** Django Backend (PostgreSQL)
- **Related Components:** `faculties` module
- **Time First Observed:** Load testing phase

## Investigation Steps

### 1. Initial Diagnosis
The k6 load test results highlighted severe degradation on the GET list endpoints. We instituted a TDD requirement to write a test suite utilizing `self.assertNumQueries()` to capture the exact SQL execution count.

### 2. Root Cause Analysis
- `FacultySerializer` included a `.count` method directly on a related field (`source='departments.count'`), which unconditionally triggers `SELECT COUNT(*)` for every single faculty.
- The `get_departments_list` method mapped the departments using `obj.departments.all()`, leading to another N queries because departments weren't prefetched in the base queryset.

### 3. Key Findings
- Data access was mixed with API routing logic (ViewSet) and presentation logic (Serializer).
- There was no dedicated selector layer for optimizing cross-table queries.

## Root Cause
A lack of separation between data access and API routing led to missing optimizations (annotations and prefetching). This caused an N+1 query proliferation whenever nested fields were serialized.

## Prevention / Rule
**Guardrail:** Mandate the use of the Service/Selector pattern (Clean Architecture). All read queries that span relationships must be isolated within a `selectors.py` file using explicit `.select_related()`, `.prefetch_related()`, and `.annotate()`, which must then be called by the ViewSet. Serializers must not query the database.

By enforcing this structural separation, data access is decoupled from presentation, and any missing prefetches can be audited or trapped by `assertNumQueries` tests during development.

## Solution

### Immediate Fix
- Implemented `FacultySelector` with `.select_related('institution')`, `.prefetch_related('departments')`, and `.annotate(departments_count_annotation=Count('departments', distinct=True))`.
- Updated `FacultyViewSet.get_queryset` to pass the base queryset to `FacultySelector.get_faculties()`, preserving `InstitutionalIsolationMixin` multi-tenancy rules.
- Updated `FacultySerializer` to replace the explicit `.count` string source with a `SerializerMethodField` that reads from the cached annotation.

### Long-term Fix
Roll out the Clean Architecture (Services and Selectors) pattern across the entire backend, particularly targeting the remaining heavy endpoint (`/users/roles/`), under strict TDD conditions.

## Prevention
- [x] Code changes required (TDD tests implemented with `assertNumQueries`)
- [ ] Roll out to remaining modules

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
