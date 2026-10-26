# Scholarships Report: Missing Schema Fields and a Latent Q-Scoping Bug

**Date:** 2026-10-26
**Project:** TESC
**Severity:** Medium (both were latent - never triggered in production until this session's new feature exercised the unused code path)
**Status:** Fixed, verified against real production data on `tesc-prod`'s `green` color

## Symptoms / Discovery Context

Building a real filter bar + table for the Scholarships page (previously
charts-only, always called its backend endpoint with an empty `filters`
dict), two real backend bugs surfaced - both only because the new feature
was the first caller to ever exercise these code paths with real filter
values, and both caught by actually calling the live endpoint against
`tesc-prod`'s `green` color rather than trusting code review alone.

## Bug 1: Schema gap in `schema_config.py`

**Symptom:** `POST /v1/reports/dynamic/generate/` with
`"columns": [..., "institution_name", ...]` for `report_type: "scholarships"`
returned `400 {"columns":["Invalid column 'institution_name' for report type
'scholarships'"]}`.

**Root cause:** `backend/reports/schema_config.py`'s `scholarships` entry
only declared `provider_name`, `amount`, `year_awarded`, `student_id_number`,
`student_name` as selectable/filterable fields - missing
`institution_name`, `program_name`, `gender`, and `status`, even though
`dynamic_service.py`'s separate relation-key mapping already knew how to
resolve `institution_name`/`program_name`/`gender` to the right
`student__...` ORM path. The column was reachable at the query-building
level but rejected at the request-validation level first.

**Fix:** added the four fields to `schema_config.py`'s `scholarships.fields`
list.

## Bug 2: `UnboundLocalError` on `Q` for any non-students/graduates report with filters

**Symptom:** the same request, once past Bug 1, 500'd:
`UnboundLocalError: cannot access local variable 'Q' where it is not
associated with a value` at `category_q = Q()` in
`build_queryset()`.

**Root cause:** `Q` is already imported at module level
(`from django.db.models import Count, Q`), but a second,
redundant `from django.db.models import Q` existed inside the
`if report_type in ['students', 'graduates']:` branch. Python's function
scoping rule makes any name imported or assigned *anywhere* in a function
body local to that *entire* function - so the presence of that inner import
statement (regardless of whether that specific branch executes) shadowed
the module-level `Q` for the whole `build_queryset()` function. Any
report_type other than `students`/`graduates` that reached
`category_q = Q()` with a non-empty `filters` dict crashed.

This was purely latent: every existing caller for `scholarships`/
`placements`/`mobility` always called the endpoint with an empty `filters`
dict (confirmed for Scholarships - `getScholarshipsStats()` was always
called with no arguments before this session), and `category_q = Q()` sits
inside an `if filters:` guard, so the crashing line was never reached by any
report type except `students`/`graduates` (which *do* take the branch that
locally imports `Q`, masking the bug for themselves). The first time any
other report type was called with a real, non-empty filter, it broke.

**Fix:** removed the redundant local import; `Q` resolves to the
module-level import for every report type.

## Verification
Both fixes verified against real production data on `tesc-prod`'s `green`
color (not just unit-level): `POST /api/v1/reports/dynamic/generate/` for
`scholarships` with `{"current_enrollment": true}` → 200, total narrowed
534 → 509, every requested column (`institution_name`, `program_name`,
`status`, `gender`) populated in a real sample row. A combined filter
(`current_enrollment` + `status=Active` + `gender=Female`) correctly
narrowed to 378 - confirming the generic per-field filter loop and the
custom `current_enrollment` handling compose correctly together.

## References
- `reports/TESC-2026-10-26-current-enrollment-filter-and-prod-promotion.md`
  and its predecessor - the broader Current Enrollment feature and
  staging-to-prod promotion this was found during.
- Commits: `dc70c1d` (schema fields), `0615de6` (Q-scoping fix).

---

**Found By:** Claude Sonnet 5 (session with tinomupezeni), via real
end-to-end testing against production data before declaring the feature done
