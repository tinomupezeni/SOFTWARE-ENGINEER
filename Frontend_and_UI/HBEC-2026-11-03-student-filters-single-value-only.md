# Student list grade/subject filters only accepted one value each

**Date:** 2026-11-03
**Project:** HBEC
**Environment:** Production
**Severity:** Low
**Status:** Resolved

## Summary
An admin (Mutsa) reported on 2026-10-30: "I need to able to apply multiple filters at once, like grade 2 and form 5" after testing the recently-shipped grade/subject student filters (2026-10-27, sha-ac122a7). The filters were single-value only end to end — frontend single-select dropdowns, a proxy view forwarding one scalar value, and a backend queryset doing exact-match/single-containment filtering — so an admin could view Grade 2 students or Form 5 students, but never both at once in one filtered list.

## Symptoms
- Grade and Subject dropdowns on the admin Student Management page (`StudentManagementPage.tsx`) only let an admin pick one value at a time.
- Picking a second value replaced the first rather than adding to it.

## Environment Details
- **Server/Host:** HBEC STUDENT backend, ADMIN frontend/backend
- **Services Affected:** `STUDENT/hbec_backend` (`apps/internal`), `ADMIN/adminBackend` (`apps/student_management`), `ADMIN/adminFrontend` (`student-management` feature)
- **Related Components:** `StudentUserListView.get`, `StudentListView.get` (proxy), `StudentManagementPage.tsx`, `studentApi.ts`, `types/index.ts`
- **Time First Observed:** 2026-10-30

## Investigation Steps

### 1. Initial Diagnosis
Traced the filter end to end: frontend `<Select>` dropdown → `filters.grade: string` → `buildQueryString` → ADMIN proxy view → Student backend queryset filter.

### 2. Root Cause Analysis
```bash
grep -n "request.query_params.get(\"grade\")\|request.query_params.get(\"subject\")" STUDENT/hbec_backend/apps/internal/views.py
grep -n "handleGradeFilter\|handleSubjectFilter" ADMIN/adminFrontend/src/features/student-management/pages/StudentManagementPage.tsx
```

### 3. Key Findings
- Student backend (`StudentUserListView.get`, `apps/internal/views.py`): `grade = request.query_params.get("grade")` → `qs.filter(student_profile__grade=grade)` (exact match on one value); `subject` likewise via `.filter(student_profile__subjects__contains=[subject])` — both read a single scalar, no `__in=` variant existed.
- ADMIN proxy (`StudentListView.get`, `apps/student_management/views.py`) just forwards whatever single string value it receives — not itself a blocker once the string could carry multiple values, since it never parses or validates the param.
- Frontend (`StudentManagementPage.tsx`): both dropdowns were the single-value shadcn `<Select>` component, bound to scalar `filters.grade`/`filters.subject` strings, even though a ready-made `MultiComboBox` component already existed in the codebase (`components/ui/combobox.tsx`) and was unused for this feature.

## Root Cause
The original "Students Filtering" feature (2026-10-27) was built single-value throughout — dropdown, proxy, and backend queryset — with no path to request more than one grade or subject at a time.

## Prevention / Rule
**Guardrail:** When adding a filter dropdown backed by a fixed option list (grade, subject, status, etc.), default to the existing `MultiComboBox` component unless the field is genuinely single-valued by definition (e.g. a boolean status) — reviewers should ask "could an admin reasonably want more than one of these at once?" before accepting a single-select for a categorical filter.

This closes the specific gap here (nobody asked that question for grade/subject) without blocking genuinely single-valued filters like active/inactive status.

## Solution

### Immediate Fix
N/A — no incident, just a missing capability.

### Long-term Fix
- Backend (`STUDENT/hbec_backend/apps/internal/views.py`): `grade` and `subject` params now accept comma-separated values. Grade uses `grade__in=[...]`; subject does an OR of `subjects__contains=[s]` per value (JSON list field, no native "any of" lookup).
- ADMIN proxy (`apps/student_management/views.py`): docstring updated to document the comma-separated contract — no code change needed, it already forwarded the raw string unparsed.
- Frontend: swapped both dropdowns for the existing `MultiComboBox` component; `filters.grade`/`filters.subject` are now `string[]`; `buildQueryString` (`studentApi.ts`) now joins array values with commas.
- Tests: added 3 backend tests (multi-grade, multi-subject, blank-entry tolerance in the comma list) to the existing `test_student_filter_by_grade_subject.py` — all 7 tests in that file pass. Frontend `tsc --noEmit` clean.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None — first report of this limitation since the feature shipped 2026-10-27.

## References
- `STUDENT/hbec_backend/apps/internal/views.py` (`StudentUserListView.get`)
- `ADMIN/adminBackend/apps/student_management/views.py` (`StudentListView`)
- `ADMIN/adminFrontend/src/features/student-management/pages/StudentManagementPage.tsx`
- `ADMIN/adminFrontend/src/components/ui/combobox.tsx` (`MultiComboBox`)
- `STUDENT/hbec_backend/apps/internal/tests/test_student_filter_by_grade_subject.py`

---

**Resolved By:** Claude (session with Tinotenda Mupezeni)
**Time to Resolution:** Same session as investigation
