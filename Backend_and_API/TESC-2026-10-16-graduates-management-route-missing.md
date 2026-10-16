# [TESC] Graduates Management Route Returns 404 in Staging

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** Low
**Status:** Resolved

## Summary
The endpoint checklist initially treated `/api/academic/graduates-mgmt/` as a list route and reported a false failure. `GraduateViewSet` is a `GenericViewSet` with custom actions only, so the base route correctly returns HTTP 404. The intended listing endpoint is `/api/academic/graduates-mgmt/records/`, which passes in staging.

## Symptoms
- `GET /api/academic/graduates-mgmt/` returns Django HTTP 404 by design.
- `GET /api/academic/graduates-mgmt/records/` returns HTTP 200.
- Other graduate actions (`template`, `bulk-actions`, `bulk-upload`, `eligible`, and `confirm-auto`) are registered under the same prefix.

## Environment Details
- **Server/Host:** TESC staging Docker backend
- **Services Affected:** Graduate management API
- **Related Components:** `backend/academic/urls.py`, `backend/academic/app_views/graduate_views.py`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran the route as part of the authenticated endpoint matrix after all other read-only academic endpoints responded successfully.

### 2. Root Cause Analysis
Confirmed the deployed source contains `router.register(r'graduates-mgmt', GraduateViewSet, basename='graduate-mgmt')`. The viewset inherits `GenericViewSet`, not `ModelViewSet`, and defines no `list()` method. Django REST Framework therefore registers only the declared `@action` routes.

```text
GET /api/academic/graduates-mgmt/ -> 404 (expected)
GET /api/academic/graduates-mgmt/records/ -> 200
```

### 3. Key Findings
- The source declaration and live route behavior are consistent.
- The checklist used the wrong base route for a custom-action-only viewset.
- The frontend already uses the correct `/records/` route.

## Root Cause
The audit checklist incorrectly inferred a conventional list route from the router prefix. `GraduateViewSet` intentionally exposes graduate records through its custom `records` action.

## Prevention / Rule
**Guardrail:** Generate endpoint checklist entries from Django's resolved URL patterns and include custom `@action` routes, rather than assuming every router registration has a base list endpoint.

This distinguishes intentional 404 base routes from real deployment drift and ensures custom action endpoints are tested.

## Solution

### Immediate Fix
Corrected the checklist: the base route is **NOT_APPLICABLE**, and `/api/academic/graduates-mgmt/records/` is **PASS** after an authenticated staging request returned HTTP 200.

### Long-term Fix
Have the endpoint audit derive route coverage from Django's URL resolver and add focused tests for each graduate custom action.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- None.

## References
- `backend/academic/urls.py`
- `backend/academic/app_views/graduate_views.py`
- Session endpoint checklist: `academic-graduates-list`

---

**Resolved By:** Copilot
**Time to Resolution:** Same verification session
