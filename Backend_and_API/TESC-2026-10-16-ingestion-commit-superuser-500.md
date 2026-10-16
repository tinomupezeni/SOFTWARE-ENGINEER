# [TESC] Ingestion Commit Returned 500 Without Institution Context

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The ingestion commit endpoint attempted to access `request.user.institution.id` when the authenticated user had no institution. A superuser submitting otherwise valid-shaped data therefore received HTTP 500 instead of the documented institution-required validation response.

## Symptoms
- `POST /api/academic/ingestion/commit/faculties/` with data and no `institution_id` returned HTTP 500.
- The exception was caused by `None.id`.

## Environment Details
- **Server/Host:** TESC staging Docker backend
- **Services Affected:** Bulk-ingestion commit validation
- **Related Components:** `backend/academic/app_views/ingestion_views.py`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran a safe invalid-input probe for the pending ingestion commit endpoint using a fresh staging superuser token.

### 2. Root Cause Analysis
The endpoint checked only whether the request user had an `institution` attribute, not whether that relation contained an institution object, before dereferencing `.id`.

### 3. Key Findings
- Institution users were unaffected because they have an institution relation.
- Superusers can reach the endpoint but do not necessarily have institution context.
- The correct response for this request is HTTP 400 with an institution-required message.

## Root Cause
The nullability of the user-to-institution relation was not guarded before accessing its ID.

## Prevention / Rule
**Guardrail:** Resolve optional tenant context with `getattr(..., None)` and validate it before dereferencing IDs in every tenant-scoped endpoint.

This prevents role-dependent null relations from becoming server errors.

## Solution

### Immediate Fix
Updated the ingestion commit view to check the institution object itself before reading `.id`. After redeployment, the same request returns HTTP 400: `Institution ID is required`.

### Long-term Fix
Add role-matrix tests for ingestion endpoints using both institution-admin and superuser identities.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `backend/academic/app_views/ingestion_views.py`
- `/api/academic/ingestion/commit/{module_type}/`

---

**Resolved By:** Copilot
**Time to Resolution:** Same verification session
