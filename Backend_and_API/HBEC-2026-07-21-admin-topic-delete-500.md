# Admin Topic Deletion 500 Internal Server Error

**Date:** 2026-07-21
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
When attempting to delete a curriculum topic in the Admin Portal (`DELETE /api/curriculum/topics/{id}/`), the backend was responding with a 500 Internal Server Error, preventing users from removing topics.

## Symptoms
- The frontend received a 500 status code on `DELETE https://admin.hbca.tech/api/curriculum/topics/{id}/`
- The user observed a generic error or silent failure depending on the UI state, as the delete operation failed entirely.
- The `hbec-admin-backend` logs showed a fatal `FieldError` followed by an `AttributeError`.

## Environment Details
- **Server/Host:** VPS
- **Services Affected:** `hbec-admin-backend`, `hbec-admin-worker`
- **Related Components:** Django REST Framework View (`TopicDetailView`)
- **Time First Observed:** 2026-07-21 16:05:00 UTC

## Investigation Steps

### 1. Initial Diagnosis
Checked the backend Docker container logs for `hbec-admin-backend` during the deletion attempt:
```bash
docker logs --tail 100 hbec-admin-backend
```

### 2. Root Cause Analysis
The logs revealed the exact trace of the 500 error:
```json
"message": "Internal Server Error: /api/curriculum/topics/019f856b-d0b2-736b-be80-e19905630011/", 
"error.type": "FieldError", 
"error.message": "Invalid field name(s) given in select_related: 'release'. Choices are: subject, parent"
```
The view `TopicDetailView` in `apps/curriculum/views.py` was attempting to optimize the query by preloading a related field called `release` which didn't exist on the `Topic` model.

### 3. Key Findings
- **Finding 1:** `TopicDetailView` incorrectly defined `queryset = Topic.objects.select_related("subject", "release").prefetch_related("objectives", "children")`
- **Finding 2:** Removing `"release"` exposed a secondary bug. The subsequent `prefetch_related("objectives")` also failed because the `Topic` model does not have an `objectives` relationship, resulting in:
```json
"error.message": "Cannot find 'objectives' on Topic object, 'objectives' is an invalid parameter to prefetch_related()"
```

## Root Cause
The `TopicDetailView` queryset was misconfigured with invalid related fields (`release` and `objectives`) for Django's ORM optimization methods (`select_related` and `prefetch_related`). When DRF called `self.get_object()` during the `destroy` method, Django attempted to execute the invalid ORM query and crashed with a 500 error.

## Solution

### Immediate Fix
Edited the `TopicDetailView` queryset in `apps/curriculum/views.py` to remove the invalid fields:

```python
# Before
queryset = Topic.objects.select_related("subject", "release").prefetch_related("objectives", "children")

# After
queryset = Topic.objects.select_related("subject", "parent").prefetch_related("children")
```

The fix was applied directly to the running containers on the VPS:
```bash
scp /home/tino/Projects/HBEC/ADMIN/adminBackend/apps/curriculum/views.py hbec-vps:/tmp/views.py
ssh hbec-vps "docker cp /tmp/views.py hbec-admin-backend:/app/apps/curriculum/views.py && docker restart hbec-admin-backend"
ssh hbec-vps "docker cp /tmp/views.py hbec-admin-worker:/app/apps/curriculum/views.py && docker restart hbec-admin-worker"
```

### Long-term Fix
The codebase (`views.py`) was committed locally to ensure the fix persists on the next CI/CD build cycle for `ghcr.io/rest-creator/hbec-admin-backend`.

## Prevention
- [x] Code changes required (committed locally)
- [ ] Ensure Django test cases cover `DELETE` operations for API endpoints to catch invalid ORM querysets during CI.

## References
- Django `select_related` and `prefetch_related` documentation

---

**Resolved By:** Antigravity (AI)
**Time to Resolution:** ~10 minutes
