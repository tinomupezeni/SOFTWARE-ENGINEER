# Roles N+1 Database Bottleneck Fixed via Clean Architecture

**Date:** 2026-10-07
**Project:** TESC
**Environment:** Staging / Development
**Severity:** High
**Status:** Resolved

## Summary
During load testing with k6 and Grafana, the `/users/roles/` endpoint was identified as a major bottleneck. Investigation showed it was generating an N+1 cascade of queries—specifically, fetching permissions twice for every role (23 queries for just 10 roles), leading to significant latency.

## Symptoms
- The `/users/roles/` endpoint exhibited high response latency under load.
- Django generated 2 extra queries per Role to satisfy the `SlugRelatedField` and nested `PermissionSerializer` for the role's permissions.

## Environment Details
- **Server/Host:** TESC Staging
- **Services Affected:** Django Backend (PostgreSQL)
- **Related Components:** `users` module (`RoleViewSet`, `RoleSerializer`)
- **Time First Observed:** Load testing phase

## Investigation Steps

### 1. Initial Diagnosis
A strict TDD test (`RolePerformanceTestCase.test_role_list_contract_and_performance`) was written using `assertNumQueries` to track exactly how many SQL queries were dispatched when requesting a list of 10 roles.

### 2. Root Cause Analysis
The test revealed that 23 queries were executed. `RoleSerializer` defines two fields targeting the same related object:
- `permissions = serializers.SlugRelatedField(slug_field='codename', many=True)`
- `permissions_detail = PermissionSerializer(source='permissions', many=True)`

Without prefetching, DRF triggers a database hit for each of these fields *for every single role in the list*.

### 3. Key Findings
- Similar to the `faculties` module, there was no separation between data access and the API layer.
- `RoleViewSet` was fetching base querysets (`Role.objects.all()`) directly inside `get_queryset()` without any `prefetch_related` optimizations.

## Root Cause
Missing `.prefetch_related('permissions')` on the base queryset returned by the ViewSet caused DRF to individually query the database for related permissions during serialization.

## Prevention / Rule
**Guardrail:** Mandate the use of the Service/Selector pattern (Clean Architecture). All read queries must be isolated within a `selectors.py` file. Any serializer that renders nested `many=True` fields must have its corresponding base queryset optimized using `.prefetch_related()` in the selector layer.

This strict rule prevents N+1 regressions. Any unoptimized relation will immediately fail the required `assertNumQueries` test suites.

## Solution

### Immediate Fix
- Created `users/selectors.py` and implemented `RoleSelector.get_roles(queryset)` that applies `.prefetch_related('permissions')` to the given queryset.
- Updated `RoleViewSet.get_queryset()` in `users/views/settings_views.py` to route all returned querysets through `RoleSelector.get_roles()`.
- The number of queries executed for 10 roles was successfully reduced from 23 down to 4 (2 for Postgres session initialization + 1 for roles + 1 for prefetched permissions).

### Long-term Fix
This confirms that the Clean Architecture separation works effectively across different modules. The pattern should be applied to any remaining list endpoints with nested representations (e.g. users, departments).

## Prevention
- [x] Code changes required (TDD performance tests written and passed)
- [ ] Documentation to update

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
