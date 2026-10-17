# TESC students page returns the full production dataset

**Date:** 2026-10-17
**Project:** TESC
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The production `/students` page requests server-side pagination, but the
backend does not have an active pagination class for `StudentViewSet`.
Consequently, the endpoint ignores `page` and `page_size` and serializes all
42,575 production students into the browser. The page already has separate
full-queryset aggregate fields for its total, gender, and special-enrollment
cards; the intended remediation is to enable pagination only on
`StudentViewSet`, preserving those aggregate fields and avoiding a global
pagination change that could alter unrelated endpoints.

## Symptoms
- `/students` takes a long time to load because the initial request attempts
  to return the complete student dataset.
- The frontend sends `page=1&page_size=50`, but the response is not bounded to
  50 rows when the backend pagination configuration is absent.
- Total-student and other summary cards must remain based on the full filtered
  dataset, not only the visible page.

## Environment Details
- **Server/Host:** Production TESC VM, `10.50.200.35`
- **Services Affected:** `tesc-main-backend-1`; public frontend `/students`
- **Related Components:** `backend/academic/app_views/student_views.py`,
  `backend/core/settings.py`, `frontend/src/pages/Students.tsx`,
  `frontend/src/services/students.services.ts`
- **Time First Observed:** 2026-10-17
- **Production backend image:** `tinotenda762/tesc-backend:fb060cc`
- **Production backend image digest:** `sha256:9d651018a925d90e1d9328d9ebf342fe7d8f046b403dfb1a8ccd326b41dba14f`

## Investigation Steps

### 1. Initial Diagnosis
Inspected the production page bundle and source. The frontend already
maintains `currentPage`, sends `page` and `page_size`, reads `count` for page
controls, and reads `total_students`, `male_students`, `female_students`, and
`disabled_count` for the summary cards.

### 2. Root Cause Analysis
Inspected the production container and Django configuration:

```bash
ssh user@10.50.200.35 \
  'docker exec tesc-main-backend-1 python manage.py shell -c \
  "from academic.app_views.student_views import StudentViewSet; \
   from django.conf import settings; \
   print(StudentViewSet.pagination_class); \
   print(settings.REST_FRAMEWORK.get(\"DEFAULT_PAGINATION_CLASS\")); \
   print(settings.REST_FRAMEWORK.get(\"PAGE_SIZE\"))"'
# pagination_class= None
# default= None
# page_size= None

ssh user@10.50.200.35 \
  'docker exec tesc-main-backend-1 python manage.py shell -c \
  "from academic.models import Student; print(Student.objects.count())"'
# student_count= 42575
```

`StudentViewSet.list()` calls `self.paginate_queryset(queryset)`. With no
view-level or project-level pagination class, DRF returns `None`, so the
fallback branch serializes the entire queryset.

### 3. Key Findings
- `frontend/src/pages/Students.tsx` already implements server-side pagination
  with 50 rows per page.
- `frontend/src/services/students.services.ts` already preserves the paginated
  response contract and full-set aggregate fields.
- `backend/academic/app_views/student_views.py` computes aggregate cards
  before pagination, which is compatible with the requested behavior.
- `backend/core/pagination.py` already defines
  `StandardResultsSetPagination` with a 100-row default, `page_size` query
  support, and a 500-row maximum.
- The pagination defaults were removed in commit `9a4a925` after an earlier
  project-wide pagination change caused API contract drift. Re-enabling them
  globally would risk changing unrelated list endpoints.
- The same silent-no-op pagination failure was previously recorded for custom
  student report actions in
  `TESC-2026-10-13-stem-students-pagination-dead-code.md`.

## Root Cause
`StudentViewSet` has no `pagination_class`, and `REST_FRAMEWORK` has no
`DEFAULT_PAGINATION_CLASS` or `PAGE_SIZE`. The frontend/backend pagination
contract was implemented on the client and in `StudentViewSet.list()`, but the
configuration required to activate DRF pagination was later removed globally.
DRF therefore silently falls through to the full-queryset serialization path.

## Prevention / Rule
**Guardrail:** add an API contract test for every paginated list endpoint that
requests `page_size=10` and asserts both `len(results) <= 10` and preservation
of the full filtered `count`/aggregate fields. This catches the silent DRF
no-op and prevents a frontend-only pagination implementation from being
mistaken for an active server-side contract.

## Solution

### Immediate Fix
No production change has been made. The proposed surgical fix is to assign
`StandardResultsSetPagination` to `StudentViewSet` only.

### Long-term Fix
- Add a focused backend regression test proving page size, page boundaries,
  `count`, and all aggregate card fields.
- Add a frontend/API contract smoke test against staging.
- Keep pagination scoped per view unless every list endpoint has an explicit
  response-contract review; do not restore project-wide defaults casually.

## Prevention
- [ ] Configuration changes needed — add view-level pagination to
      `StudentViewSet` after staging verification.
- [ ] Monitoring/alerts to add — track response size and latency for
      `/api/academic/students/`.
- [ ] Documentation to update — document the page/aggregate response contract.
- [ ] Code changes required — add backend regression coverage and deploy the
      targeted fix.

## Related Issues
- `TESC-2026-10-13-stem-students-pagination-dead-code.md`
- Commit `9a4a925`, which removed the project-wide pagination defaults.

## References
- `backend/academic/app_views/student_views.py`
- `backend/core/pagination.py`
- `backend/core/settings.py`
- `frontend/src/pages/Students.tsx`
- `frontend/src/services/students.services.ts`

---

**Resolved By:** Copilot
**Time to Resolution:** Investigation ongoing
