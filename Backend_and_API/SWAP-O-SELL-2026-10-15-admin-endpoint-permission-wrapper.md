# Admin API decorator did not enforce staff permissions

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Environment:** Development  
**Severity:** High  
**Status:** Resolved

## Summary
The first implementation of the custom admin API wrapped Django REST Framework decorators in a helper function incorrectly. The resulting endpoint returned dashboard data to unauthenticated requests instead of enforcing the staff permission.

## Symptoms
- `GET /api/admin/summary/` returned `200` without an Authorization header.
- The custom admin frontend could have exposed operational data if deployed in that state.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Django admin API
- **Related Components:** `modules.admin_api.views`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Called the new admin summary endpoint without credentials after adding the frontend.

### 2. Root Cause Analysis
The view functions used a custom `staff_only` wrapper around `api_view` and `permission_classes`. The decorator composition did not produce the expected DRF permission-bearing view.

### 3. Key Findings
- The endpoint was reachable without authentication.
- The permission class itself was correct.
- Explicit DRF decorators on each endpoint are clear and enforceable.

## Root Cause
The custom decorator abstraction obscured DRF's required decorator order and failed to attach the permission metadata to the final view.

## Prevention / Rule
**Guardrail:** Use the explicit DRF pattern `@api_view(...)` followed by `@permission_classes(...)` on every protected function-based API view, and include an unauthenticated request check in endpoint validation.

This keeps permission metadata attached to the actual view returned to Django and catches accidental public exposure.

## Solution

### Immediate Fix
Replaced the helper wrapper with explicit `@api_view(['GET'])` and `@permission_classes([IsStaffUser])` decorators on all admin endpoints.

### Long-term Fix
Add authenticated and unauthenticated API tests for the admin surface as the endpoint set grows.

## Prevention
- [x] Code changes required
- [x] Authentication/authorization check required
- [x] Documentation updated

## References
- `backend/modules/admin_api/permissions.py`
- `backend/modules/admin_api/views.py`
- `admin/src/api.ts`

---

**Resolved By:** Copilot  
**Time to Resolution:** During implementation
