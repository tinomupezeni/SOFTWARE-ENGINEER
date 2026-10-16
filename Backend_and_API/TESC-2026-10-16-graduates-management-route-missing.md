# [TESC] Graduates Management Route Returns 404 in Staging

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** High
**Status:** Investigating

## Summary
The deployed staging URL configuration registers a `GraduateViewSet` at `/api/academic/graduates-mgmt/`, but requests to that route return HTTP 404. The route is present in the deployed `academic/urls.py` source, yet Django does not resolve the expected router route name or URL, so graduate-management endpoint coverage cannot pass.

## Symptoms
- `GET /api/academic/graduates-mgmt/` returns Django HTTP 404.
- Alternate forms without or with trailing slash also return 404.
- Other academic router endpoints, including students and placements, return HTTP 200.

## Environment Details
- **Server/Host:** TESC staging Docker backend
- **Services Affected:** Graduate management API
- **Related Components:** `backend/academic/urls.py`, `backend/academic/app_views/graduate_views.py`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran the route as part of the authenticated endpoint matrix after all other read-only academic endpoints responded successfully.

### 2. Root Cause Analysis
Confirmed the deployed source contains `router.register(r'graduates-mgmt', GraduateViewSet, basename='graduate-mgmt')`. The live Django resolver still returned no matching route for the expected list endpoint, and URL reversing for `graduate-mgmt-list` failed.

```bash
GET /api/academic/graduates-mgmt/ -> 404
reverse('graduate-mgmt-list') -> NoReverseMatch
```

### 3. Key Findings
- The source declaration and live route behavior disagree.
- This is isolated to the graduate-management router registration/URL loading path.
- The failure is not caused by authentication; authenticated requests reach Django and receive Page Not Found.

## Root Cause
Not yet isolated. The deployed URL resolver is not exposing the registered graduate-management route despite the route declaration being present in the container source.

## Prevention / Rule
**Guardrail:** Add a deployment smoke assertion that resolves and requests every registered router list route, including graduate management, before staging is considered healthy.

This catches URL-loader or deployment-artifact drift immediately instead of allowing a declared-but-unreachable endpoint into production.

## Solution

### Immediate Fix
No production change made. The endpoint is recorded as **FAIL** in the session endpoint checklist.

### Long-term Fix
Inspect `GraduateViewSet` import/registration and the deployed image artifact, then add a focused route-resolution test for `/api/academic/graduates-mgmt/`.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `backend/academic/urls.py`
- `backend/academic/app_views/graduate_views.py`
- Session endpoint checklist: `academic-graduates-list`

---

**Resolved By:** Pending
**Time to Resolution:** Investigation recorded
