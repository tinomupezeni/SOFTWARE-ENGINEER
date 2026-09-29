# Same program listed multiple times in admin-side Student Records program filter

**Date:** 2026-09-29
**Project:** TESC
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
TESC has two portals: `inst` (institution-facing, where each institution enters
its own programs and students) and `frontend` (admin, "see everything" across
all institutions). Because `Program` is modeled per-institution/department
(`unique_together = ('department', 'code')`, no uniqueness on `name`), the
same program name legitimately exists as N separate `Program` rows when N
institutions independently enter it (e.g. "Electrical Power Engineering" at
Masvingo, Bulawayo, Harare, and Mutare Polytechnics). The admin Student
Records page's Program filter dropdown was built from a `filter-options`
endpoint that deduped by `program_id`, so it listed the identical name once
per institution instead of once overall - the user's report was "some
programs are being repeated" in the filter.

## Symptoms
- On the admin Student Records page, the "Program of Study" filter dropdown
  showed the same program name several times (e.g. "ELECTRICAL POWER
  ENGINEERING" appeared 9 times).
- Selecting any one of the duplicate entries only filtered students enrolled
  at the single institution behind that particular `Program` row, silently
  missing students at every other institution offering the same program
  under its own `Program` record.

## Environment Details
- **Server/Host:** Production (`tesc-prod`, `10.50.200.35`,
  `tesc-main-backend-1` / `tesc-main-frontend-admin-v2-1` containers)
- **Services Affected:** Admin `Student Records` page filter dropdown and
  server-side filtering; PDF report generation from the same page (and,
  incidentally, from ISEOP) via the dynamic report builder
- **Related Components:**
  `backend/academic/app_views/student_views.py` (`filter_options`,
  `get_queryset`), `backend/reports/dynamic_service.py`
  (`_get_relation_filter_key`), `frontend/src/pages/Students.tsx`,
  `frontend/src/services/students.services.ts`
- **Time First Observed:** 2026-09-29

## Investigation Steps

### 1. Initial Diagnosis
Read `filter_options` in `student_views.py`, which builds the dropdown data
by `.values('program_id', 'program__name').distinct()` - distinct per ID, not
per name.

### 2. Root Cause Analysis
Checked `faculties/models.py`'s `Program` model: `name` has no uniqueness
constraint at all, only `unique_together = ('department', 'code')`. Queried
production directly over SSH to confirm the shape of the duplication was
"same name, different institution/department", not corrupt data:

```bash
docker exec tesc-main-backend-1 python manage.py shell -c "
from django.db.models import Count
from faculties.models import Program
dupes = Program.objects.values('name').annotate(c=Count('id')).filter(c__gt=1).order_by('-c')
print(f'{len(dupes)} duplicate program names found')
"
# -> 137 duplicate program names
docker exec tesc-main-backend-1 python manage.py shell -c "
from faculties.models import Program
for p in Program.objects.filter(name='ELECTRICAL POWER ENGINEERING').select_related('department','institution'):
    print(p.id, p.code, p.department, p.institution)
"
```
This showed the same program name existing once per institution (Masvingo,
Bulawayo x2, Harare x3, Mupfure) with different `code`/`department`/
`institution` - i.e. legitimate independent data entry via the `inst` portal,
not a data-corruption bug. (Separately found ~96 rows with garbage names
literally `"NAN"`/`"2026"`, unrelated to this ticket - noted for a future
data-cleanup pass but out of scope here since the user confirmed the
duplication they cared about was the cross-institution case.)

### 3. Key Findings
- `Program` is intentionally scoped per institution; there is no single
  canonical "program" record shared across institutions, so any
  admin-facing view that lists "all programs" needs to explicitly dedupe by
  name rather than by row identity.
- The report-builder's field-key mapping (`dynamic_service.py`) had a
  matching latent bug: for `report_type` `students`/`graduates`/
  `placements`/`scholarships`/`mobility`, the filter key `program_name` was
  mapped to `program_id` (or `student__program_id`) - i.e. it expected an
  ID despite the key's name. This had been silently compensated for by a
  frontend bug in `Students.tsx` that sent the selected dropdown's numeric
  `id` under the `program_name` key - two bugs canceling out for the
  single-institution case, but neither correct nor extensible.

## Root Cause
Two compounding issues:
1. The admin filter-options endpoint deduped candidate programs by
   `program_id` instead of by `program__name`, so a name entered
   independently by multiple institutions appeared once per institution in
   the dropdown, and filtering by the selected row's ID only ever matched
   one institution's students.
2. The dynamic report builder's `program_name` filter key was wired to the
   `program_id` field, an unrelated latent bug that would have surfaced
   correctly (as a crash) the moment the frontend was fixed to send an
   actual name instead of an ID.

## Prevention / Rule
**Guardrail:** Any admin-facing "all X across institutions" filter/report
built on a per-institution model must state explicitly whether it dedupes
by name or by row identity - add a one-line comment at the `.values()`/
`.distinct()` call recording that choice, so a future edit doesn't
silently reintroduce identity-based deduping on a name-shared model.
Additionally, a report-builder filter-key-to-field mapping should never map
a `_name` key to an `_id` field or vice versa; a coding-standard/lint rule
that flags `'*_name': '*_id'` (or the reverse) in `_get_relation_filter_key`
would have caught this immediately.

This closes the gap because the actual data model choice (per-institution
`Program` rows, no cross-institution identity) is invisible unless it's
written down at the point where a list is built from it - the next
developer touching this endpoint won't reintroduce the bug without also
removing the comment that explains why.

## Solution

### Immediate Fix
- `backend/academic/app_views/student_views.py`: `filter_options` now
  dedupes programs by `program__name` only (drops `program_id` from the
  response); `get_queryset` gained a `program_name` query param that
  filters `Q(program__name=...)`, matching students across every
  institution offering that program.
- `backend/reports/dynamic_service.py`: `_get_relation_filter_key` now maps
  `program_name` to `program__name` (or `student__program__name`) instead
  of `program_id`/`student__program_id`, for all five affected report
  types.
- `frontend/src/services/students.services.ts`: `StudentFilterOptionsResponse.programs`
  changed from `{id, name}[]` to `string[]`.
- `frontend/src/pages/Students.tsx`: Program filter dropdown now keyed/valued
  by name; `queryFilters` sends `program_name` (a name) instead of `program`
  (an id); the PDF report filter mapping now forwards the real
  `program_name` value instead of re-labeling an id.

```bash
python3 -m py_compile backend/academic/app_views/student_views.py backend/reports/dynamic_service.py
```

### Long-term Fix
The ~96 rows of garbage program names (`"NAN"`, `"2026"`, literal) found
during investigation are a separate, pre-existing data-quality issue in
production (likely from an early bulk-import batch) - flagged for a
follow-up data-cleanup pass, not fixed in this change since it's unrelated
to the filter-dedup bug the user reported.

## Prevention
- [x] Code changes required (done this session)
- [ ] Data cleanup: audit/remove the `"NAN"`/`"2026"` garbage `Program` rows
      in production
- [ ] Consider a case-insensitive/trimmed uniqueness check on
      `(institution, name)` at Program-creation time in the `inst` portal to
      stop `"Accountancy"` vs `"ACCOUNTANCY"` case-variant duplicates from
      accumulating going forward

## Related Issues
- None filed yet for the `"NAN"`/`"2026"` garbage-data cleanup.

## References
- `backend/faculties/models.py` (`Program` model, `unique_together`)
- `backend/academic/app_views/student_views.py`
- `backend/reports/dynamic_service.py`
- `frontend/src/pages/Students.tsx`
- `frontend/src/services/students.services.ts`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~45 minutes from report to verified fix
