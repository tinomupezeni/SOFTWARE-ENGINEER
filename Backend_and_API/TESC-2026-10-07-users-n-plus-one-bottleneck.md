# Users N+1 Database Bottleneck Fixed via Clean Architecture

**Date:** 2026-10-07
**Project:** TESC
**Environment:** Staging / Development
**Severity:** High
**Status:** Resolved

## Summary
Following the detection of an N+1 issue in the `/users/roles/` and `/faculties/faculties/` endpoints, an audit of the `/users/users/` endpoint revealed a massive N+1 query explosion. The endpoint generated 43 database queries to fetch just 10 users because it individually queried the database for each user's related Role, Department, and Role Permissions.

## Symptoms
- Extreme latency and database load scaling linearly with the number of users returned on the `/users/users/` endpoint.
- For N users, the backend generated `1 + N*4` database queries.

## Environment Details
- **Server/Host:** TESC Staging
- **Services Affected:** Django Backend (PostgreSQL)
- **Related Components:** `users` module (`UserViewSet`, `UserSerializer`)
- **Time First Observed:** During architecture audit following Phase 2 load testing fixes.

## Investigation Steps

### 1. Initial Diagnosis
A strict TDD test (`UserPerformanceTestCase.test_user_list_contract_and_performance`) was written using `assertNumQueries(6)` to track SQL execution count.

### 2. Root Cause Analysis
The test failed, revealing 43 queries executed. `UserSerializer` natively nests both `RoleSerializer` and `DepartmentSerializer`. Because the base queryset in `UserViewSet.get_queryset()` was unoptimized, DRF was forced to fetch:
1. The user's role
2. The user's department
3. The role's permissions list (via `SlugRelatedField`)
4. The role's full permissions details (via nested serializer)
...individually for every single user.

### 3. Key Findings
- Missing backend `select_related` and `prefetch_related` optimizations on deeply nested serializers.

## Root Cause
A lack of a dedicated Data Access / Selector layer meant that API views returned unoptimized base querysets (`CustomUser.objects.filter(...)`), failing to populate the relationship caches needed by DRF serializers.

## Prevention / Rule
**Guardrail:** Mandate the use of the Service/Selector pattern (Clean Architecture). All read queries must be isolated within a `selectors.py` file. Any queryset that feeds into a serializer containing nested relations (either via `SerializerMethodField`, `SlugRelatedField`, or nested serializers) must be explicitly optimized using `.select_related()` for ForeignKeys and `.prefetch_related()` for ManyToMany/Reverse relations.

This rule actively defends against query amplification, and adherence is verified via strict `assertNumQueries` tests.

## Solution

### Immediate Fix
- Expanded `users/selectors.py` to include `UserSelector.get_users(queryset)` which applies `.select_related('role', 'department')` and `.prefetch_related('role__permissions')`.
- Updated `UserViewSet.get_queryset()` to funnel all reads through this selector.
- The number of queries executed for 10 users dropped dramatically from 43 to 4 (2 for Postgres session initialization + 1 massive join query + 1 prefetch for permissions).

### Long-term Fix
All heavy list endpoints in the `faculties` and `users` apps have now been refactored to Clean Architecture standards.

## Prevention
- [x] Code changes required (TDD performance tests written and passed)
- [ ] Code-review checklist updated for nested serializer optimizations

---

**Resolved By:** Antigravity
**Time to Resolution:** 15 minutes
