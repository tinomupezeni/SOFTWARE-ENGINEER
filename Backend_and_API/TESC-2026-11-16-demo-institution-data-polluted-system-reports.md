# ZCHPC demo/sales account's data was skewing every system-wide report and dashboard

**Date:** 2026-11-16
**Project:** TESC (ScalarEye Central Data System)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
ZCHPC (`academic_institution.id=21`) is a demo/sales account used to show
the system to prospective customers, not a real tenant. There was no flag
distinguishing it from a real institution, so every system-wide aggregate -
the national dashboard, the institution overview table, the admissions
analysis dashboard, ISEOP stats, and Report Studio's superuser-wide
queries - pulled its 341 students / 66 graduates / 26 faculties / 11
programs into the real production totals, reported and read by staff as if
they were genuine figures.

## Symptoms
- Not a crash or error - a silent data-correctness issue, surfaced by the
  user explicitly asking to review what ZCHPC's data actually was and why
  it appeared on the main system's reports.
- No alert would have caught this: every endpoint returned 200 with
  plausible-looking, just-wrong numbers.

## Environment Details
- **Server/Host:** tesc-prod (10.50.200.35), Postgres 15 container
  `tesc-main-db-1`, database `tesc_db`
- **Services Affected:** National dashboard stats, institution overview,
  admissions analysis dashboard, ISEOP stats, Report Studio (dynamic
  reports) for superusers
- **Related Components:** `backend/academic/app_views/admin_views.py`,
  `backend/academic/app_views/student_views.py`,
  `backend/academic/services/student_counts.py`,
  `backend/analysis/views/admissions_views.py`, `backend/iseop/views.py`,
  `backend/reports/dynamic_service.py`
- **Time First Observed:** 2026-11-16, during a review of ZCHPC's data
  footprint requested by the user

## Investigation Steps

### 1. Initial Diagnosis
SSH'd into `tesc-prod`, queried `academic_institution` for ZCHPC and its
row counts across students/graduates/faculties/programs/facilities to
understand the institution's actual footprint before deciding how to
exclude it.

### 2. Root Cause Analysis
Grepped the backend for every place that builds an institution-wide
queryset without a per-institution filter:
```bash
grep -rn "Institution.objects.all()\|IseopStudent.objects.all()" backend --include="*.py"
```
Confirmed `Institution` has no `is_demo`/`is_test` flag and no existing
exclusion mechanism (`status='Active'` is used in exactly one place and is
semantically unrelated - ZCHPC's status is legitimately `Active`).

### 3. Key Findings
- `academic/app_views/admin_views.py::DashboardStatsView` and
  `InstitutionOverviewView` aggregated `Institution`/`Student`/`IseopStudent`
  with no exclusion when no `institution_id` was passed (the default,
  system-wide view).
- `academic/services/student_counts.py::student_totals_by_institution()`
  and `duration_enrolled_students_by_institution()` had no exclusion at
  all - always system-wide.
- `reports/dynamic_service.py::build_queryset()` only scopes to the
  caller's own institution for non-superusers; superusers (who run
  Report Studio's cross-institution reports) got the full unfiltered
  queryset.
- `analysis/views/admissions_views.py::AdmissionsAnalysisView`,
  `iseop/views.py`'s `stats` action, and
  `academic/app_views/student_views.py::dashboard_stats` followed the
  same pattern: filtered by `institution_id` when given, otherwise
  unfiltered for superusers.
- Institution-scoped access (an explicit `institution_id`, or ZCHPC's own
  users viewing their own portal) must keep working unchanged - ZCHPC
  still needs to log in and demo the system normally.

## Root Cause
`Institution` had no way to mark a tenant as non-production (demo/sales),
so every "system-wide, no institution_id given" code path - which assumes
every institution in the table is a real one - necessarily included ZCHPC.

## Prevention / Rule
**Guardrail:** Any new system-wide aggregation over `Institution` (or a
model with an `institution`/`institution_id` FK) must route through a
query that excludes `is_demo=True`, the same way it's expected to respect
tenant isolation for non-superusers. A code-review checklist item for this
app: "does this queryset only exclude demo institutions when no explicit
`institution_id` is given, and does it still work for superusers?"

This closes the actual gap - there was never a single chokepoint instutions
went through, so each of the 6 call sites had to independently remember to
exclude demo data; the field now at least makes "is this institution real"
a first-class, queryable fact instead of tribal knowledge.

## Solution

### Immediate Fix
- Added `Institution.is_demo` (`BooleanField`, default `False`) via
  `backend/academic/migrations/0033_institution_is_demo.py`.
- Data migration `0034_flag_zchpc_as_demo.py` sets `is_demo=True` for the
  institution named `ZCHPC` (reversible).
- Excluded `is_demo=True` institutions from every system-wide aggregate
  found in the investigation, while leaving explicit per-institution
  (`institution_id` given) and non-superuser institution-scoped paths
  untouched:
  - `DashboardStatsView`, `InstitutionOverviewView`
    (`academic/app_views/admin_views.py`)
  - `student_totals()`, `student_totals_by_institution()`,
    `duration_enrolled_students_by_institution()`
    (`academic/services/student_counts.py`)
  - `dashboard_stats` action (`academic/app_views/student_views.py`)
  - `AdmissionsAnalysisView` (`analysis/views/admissions_views.py`)
  - `IseopStudentViewSet.stats` (`iseop/views.py`)
  - `DynamicReportService.build_queryset` superuser path
    (`reports/dynamic_service.py`)

```bash
python -m py_compile academic/models.py academic/services/student_counts.py \
  academic/app_views/admin_views.py academic/app_views/student_views.py \
  analysis/views/admissions_views.py iseop/views.py reports/dynamic_service.py \
  academic/migrations/0033_institution_is_demo.py \
  academic/migrations/0034_flag_zchpc_as_demo.py   # clean
```

### Long-term Fix
Not pursued in this session: consolidate the 6 call sites behind a single
`reportable institutions` helper (e.g. on `InstitutionSelector`) so future
system-wide views can't forget the exclusion. Left as a follow-up since the
immediate per-call-site fix was sufficient to close the actual leak and a
bigger refactor wasn't requested.

## Prevention
- [x] Code changes required (done this session)
- [ ] Consolidate the 6 exclusion call sites into one shared selector
- [ ] Add a code-review checklist item for new `Institution`-wide queries

## Related Issues
None - first known instance of this gap.

## References
- `backend/academic/models.py`
- `backend/academic/migrations/0033_institution_is_demo.py`
- `backend/academic/migrations/0034_flag_zchpc_as_demo.py`
- `backend/academic/app_views/admin_views.py`
- `backend/academic/app_views/student_views.py`
- `backend/academic/services/student_counts.py`
- `backend/analysis/views/admissions_views.py`
- `backend/iseop/views.py`
- `backend/reports/dynamic_service.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~1 hour from request to committed fix (branch `feat/hide-demo-institution-reports`, not yet deployed)
