# Staff report builder's faculty/department filter mapping had the same id-vs-name mismatch as the Program filter bug (dead code, preventively fixed)

**Date:** 2026-09-29
**Project:** TESC
**Environment:** Production
**Severity:** Low
**Status:** Resolved

## Summary
While searching for other instances of the duplicate-Program-filter bug
(logged separately in
`TESC-2026-09-29-duplicate-programs-in-admin-filter.md`), found the same
mapping mistake in `backend/reports/dynamic_service.py`'s
`_get_relation_filter_key` for `report_type='staff'`: `faculty_name` and
`department_name` were mapped to `faculty_id`/`department_id` instead of
`faculty__name`/`department__name`, even though `Faculty` and `Department`
are scoped per-institution exactly like `Program` (no global name
uniqueness). Unlike the Program case, this was never actually triggered in
production - `schema_config.py`'s `staff` schema doesn't declare
`faculty_name`/`department_name` as filterable fields, so `get_field_by_key`
returns `None` for them and the mapping is dead code today. Fixed
preventively before it could ever fire.

## Symptoms
None observed - no live bug. This was found by deliberately searching for
the same bug shape elsewhere after fixing the Program filter issue, not by
a user report.

## Environment Details
- **Server/Host:** N/A (dead code path, not exercised in production)
- **Services Affected:** None currently; would have affected staff report
  filtering by faculty/department the moment those fields were made
  filterable
- **Related Components:** `backend/reports/dynamic_service.py`
  (`_get_relation_filter_key`, `group_field_map`),
  `backend/reports/schema_config.py` (`staff` schema)
- **Time First Observed:** 2026-09-29

## Investigation Steps

### 1. Initial Diagnosis
After fixing the Program-filter dedup bug, spawned a targeted search across
the codebase for the same "per-institution-scoped model keyed/filtered by
row ID instead of name" pattern on other pages/entities (Department,
Faculty, other filter-options endpoints, other admin pages, bulk-upload
matching).

### 2. Root Cause Analysis
Confirmed `Faculty`/`Department` (`backend/faculties/models.py`) are scoped
per-institution the same way `Program` is (`Department` is only
`unique_together = ('faculty', 'name')` - no cross-institution identity).
Checked `_get_relation_filter_key['staff']` against the same file's
`group_field_map['staff']` (used for group-by, not filtering) and found they
disagreed: group-by already correctly uses `faculty__name`/
`department__name`, while the filter-key mapping used `faculty_id`/
`department_id`. Checked `schema_config.py`'s `staff` field list and
confirmed `faculty_name`/`department_name` are absent from it entirely, so
`get_field_by_key(report_type, key)` returns `None` for both keys and
`build_queryset` skips them before ever reaching the broken mapping -
confirming no live path exercises this code today.

### 3. Key Findings
- The bug shape is identical to the Program/`program_name` bug: a
  `*_name` filter key silently expecting an ID value.
- It was inert only by accident (the schema simply never exposed these two
  fields as filterable), not by any deliberate guard - the moment someone
  adds `faculty_name`/`department_name` to the staff schema's filterable
  fields (a very plausible future change, since they're already selectable/
  groupable), the same silent-wrong-filter bug would reappear.

## Root Cause
Copy-paste inconsistency: the `_get_relation_filter_key` mapping was written
assuming `faculty_name`/`department_name` behave like true per-institution-
unique lookups (map to the FK id), without checking that, like `program_name`,
they're display keys for a per-institution-scoped model with no cross-
institution identity - the same mistake made (and already fixed) for
`program_name` on students/graduates/placements/scholarships/mobility.

## Prevention / Rule
**Guardrail:** `_get_relation_filter_key` and `group_field_map` describe the
same set of relation fields for the same report_type and must never
disagree - add a one-time consistency assertion (e.g. a test or a startup
check) that for every `report_type`, any key present in both mappings
resolves to the same underlying ORM path family (either both `_id
would be wrong for a real name field, both `__name`), so mapping drift like
this is caught immediately instead of lying dormant until a schema change
activates it.

This closes the gap because the two mappings are otherwise edited
independently by whoever adds a new filterable/groupable field, with
nothing forcing them to be checked against each other.

## Solution

### Immediate Fix
`backend/reports/dynamic_service.py`: `_get_relation_filter_key['staff']`
changed `faculty_name`/`department_name` from `faculty_id`/`department_id`
to `faculty__name`/`department__name`, matching `group_field_map['staff']`.

```bash
python3 -m py_compile backend/reports/dynamic_service.py
```

### Long-term Fix
No further action needed unless `faculty_name`/`department_name` are added
to `schema_config.py`'s `staff` filterable fields in the future - at that
point this fix means they'll already filter correctly by name across
institutions rather than requiring a second bug hunt.

## Prevention
- [x] Code changes required (done this session)
- [ ] Add the cross-mapping consistency check described above (not done
      this session - flagged for later, low priority since it's a
      preventive hardening item, not an active bug)

## Related Issues
- `Backend_and_API/TESC-2026-09-29-duplicate-programs-in-admin-filter.md`
  (the live bug this preventive fix was found while searching for repeats
  of)

## References
- `backend/reports/dynamic_service.py`
- `backend/reports/schema_config.py`
- `backend/faculties/models.py` (`Faculty`, `Department` models)

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~10 minutes (found via proactive search, fixed immediately)
