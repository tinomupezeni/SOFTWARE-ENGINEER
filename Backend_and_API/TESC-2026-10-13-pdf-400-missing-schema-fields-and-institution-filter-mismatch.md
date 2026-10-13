# Staff/Graduates Download PDF 400s; PDF header ignored applied institution filter

**Date:** 2026-10-13
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
Three related bugs in the dynamic report PDF system, found in one session
after the user hit a 400 on the Staff page's Download PDF and asked "lets
also check out throughout all other reports generations." Auditing every
hardcoded PDF `columns` list against its backend schema (the same technique
used earlier this session for the `is_iseop` FieldError bug) found Staff's
and Graduates' PDF requests had always been broken, plus a separate crash
waiting to happen once institution filtering actually worked, plus the PDF
header silently ignoring any institution filter the user applied.

## Symptoms
- Staff page: `Failed to generate PDF AxiosError: Request failed with
  status code 400` on every Download PDF click, regardless of filters.
- (Latent, not yet hit) Graduates page's Download PDF would 400 the same
  way, and filtering Graduates by institution would silently match nothing
  even once the 400 was fixed.
- PDF header showed "All Institutions" even after the user applied an
  institution filter and generated the report.

## Environment Details
- **Server/Host:** tesc-staging VM, `tesc-backend-1` container
- **Services Affected:** `backend/reports/schema_config.py`,
  `backend/reports/dynamic_service.py`, `backend/reports/dynamic_views.py`,
  `backend/reports/api.py` (Reports Studio PDF path)
- **Related Components:** `frontend/src/pages/Staff.tsx`,
  `frontend/src/pages/Graduates.tsx`
- **Time First Observed:** 2026-10-13

## Investigation Steps

### 1. Initial Diagnosis
Checked nginx access logs for the failing request:
`POST /api/v1/reports/dynamic/generate/ ... "https://tesc-staging.zchpc.ac.zw/staff"`.
No application-level traceback in the backend logs, since `ReportGenerateSerializer.validate()`
rejects invalid input cleanly (a 400, not an unhandled exception) - pointed
straight at serializer-level validation rather than a runtime crash.

### 2. Root Cause Analysis
Read `ReportGenerateSerializer.validate()`
(`backend/reports/dynamic_serializers.py`): it rejects any `columns` entry
not present in `REPORT_SCHEMAS[report_type]['fields']`. Compared that
against `Staff.tsx`'s hardcoded PDF request:

```ts
columns: ['employee_id', 'full_name', 'institution_name', 'department_name', 'position', 'is_active']
```

against the `'staff'` schema, which only declared `employee_id`,
`full_name`, `position` - three of six requested columns didn't exist in
the schema at all, despite all being real `Staff` model fields/relations.

Per the user's explicit "check throughout all other report generations"
ask, grepped every page for a hardcoded `generatePDF` call (the only ones
at risk - `ReportBuilder.tsx`'s shared dialog builds its column list from
the schema itself, so it can't drift) and found `Graduates.tsx` sending
`graduation_year` as a column for `report_type: 'students'`, which also
isn't declared there (it's declared on the *`graduates`* schema, which
nothing in the frontend actually uses - `Graduates.tsx` targets
`report_type: 'students'` filtered by status).

Checked what would happen next if only the column declarations were added:
`Staff.tsx` and `Graduates.tsx` both build their institution filter
dropdown from already-loaded records' institution **name** strings (no id
available client-side), and send that name under the `institution_name`
filter key - but `_get_relation_filter_key` resolves that key to
`institution_id` for students/graduates (matching the schema-driven
`ReportBuilder`/`FilterSection.tsx`, which does send a numeric id from
`get_relation_options`). Filtering an integer `_id` column against a name
string would silently match zero rows.

Separately, read `dynamic_views.py`'s institution-name-for-PDF-header logic:
it only ever checked the logged-in user's own institution or an explicit
top-level `institution_id` field the frontend never sends - never the
`institution_name` filter actually in the request body. Same gap in the
Reports Studio PDF path (`api.py`), which never inspected the Report
Definition's filters at all for an institution value.

### 3. Key Findings
- `ReportBuilder.tsx` (7 pages) is immune to the column-mismatch class of
  bug since its columns are schema-derived; only hand-built pages with a
  hardcoded `columns` array can drift from the schema.
- The `institution_name` filter key means two different things depending
  on which page sends it: a numeric institution id (`Students.tsx`,
  `ReportBuilder`/`FilterSection.tsx`) or an institution name string
  (`Staff.tsx`, `Graduates.tsx`) - an inconsistency baked into how each
  page's filter dropdown happens to be populated, not something fixable by
  picking one canonical mapping per report_type (`Students.tsx` and
  `Graduates.tsx` share `report_type: 'students'` but disagree on which
  convention they use).

## Root Cause
1. `schema_config.py`'s `'staff'` entry and `'students'` entry were each
   missing field declarations for real model columns their own frontend
   pages had already been requesting as PDF columns
   (`institution_name`/`department_name`/`is_active` for staff,
   `graduation_year` for students) - the serializer's column whitelist
   rejected the whole request with 400.
2. The relation-filter-key mapping assumed every caller of a given
   `(report_type, key)` pair sends the same value shape (an id), which
   doesn't hold here - two pages sharing `report_type: 'students'` send
   different value types for the same `institution_name` filter key.
3. The PDF header's institution-name resolution never looked at the
   request's actual filters, only the logged-in user's own institution.

## Prevention / Rule
**Guardrail:** extend the CI guardrail proposed in
[[TESC-2026-10-13-dynamic-report-filter-fielderror-500s]] (a parametrized
test iterating every `REPORT_SCHEMAS` field through `build_queryset`) to
also assert, for every hardcoded `generatePDF`/`columns` call found in the
frontend (a small greppable set today - `Staff.tsx`, `Students.tsx`,
`Graduates.tsx`), that each listed column key exists in that report type's
schema - this is exactly the audit done by hand here, and should run
automatically so a hardcoded page's PDF columns can't silently drift from
its schema again.

For the id-vs-name filter-value ambiguity: the `_looks_like_id()` check
added to `build_queryset` (any filter value destined for an `_id` column
that isn't actually numeric falls back to the relation's `__name` path) is
the generalizable fix - a future hand-built page can send either
convention for the same filter key without needing a new mapping entry.

## Solution

### Immediate Fix
- Added `institution_name`, `department_name`, `is_active` to the `'staff'`
  schema entry, and `graduation_year` to the `'students'` schema entry, in
  `backend/reports/schema_config.py`.
- `build_queryset()` (`dynamic_service.py`) now checks, after resolving a
  key through `_get_relation_filter_key`, whether the result is an `_id`
  column and the incoming value isn't numeric - if so, it rewrites the
  filter to the relation's `__name` path instead. Also updated the
  `'staff'` mapping's `institution_name` entry directly to `institution__name`
  (Staff.tsx never had an id-based convention at all, unlike
  students/graduates, which do via `ReportBuilder`).
- `dynamic_views.py` and `api.py` (Reports Studio) now check for an applied
  `institution_name` filter (including recursing into Reports Studio's
  and/or-nested filter structure) before falling back to the user's own
  institution or "All Institutions", so the PDF header reflects what the
  report is actually scoped to.

```bash
# Verified via APIRequestFactory + force_authenticate replicating each
# page's exact PDF payload:
# Staff.tsx (filtered by institution name, and unfiltered) -> 200
# Students.tsx (institution filter as a numeric id) -> 200
# Graduates.tsx (institution filter as a name, graduation_year filter) -> 200
# PDF header institution_name correctly reflected an applied filter
# (captured via a spy on ProfessionalPDFGenerator.__init__)
```

### Long-term Fix
Automate the schema/column-consistency check described in the guardrail
above so this doesn't require a user-reported 400 to surface again.

## Prevention
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — alert on 400 rate from
      `/v1/reports/dynamic/generate/`.
- [ ] Documentation to update — none.
- [x] Code changes required — done (see Solution).

## Related Issues
- [[TESC-2026-10-13-dynamic-report-filter-fielderror-500s]] — same audit
  technique (checking every schema field against the real filter-resolution
  code path), different underlying bug class (FieldError vs. missing schema
  declarations/value-shape mismatch).

## References
- `backend/reports/schema_config.py`
- `backend/reports/dynamic_service.py`
- `backend/reports/dynamic_views.py`
- `backend/reports/api.py`
- `frontend/src/pages/Staff.tsx`, `Graduates.tsx`
- Commit: `339ee1f` on `staging`.

---

**Resolved By:** tinomupezeni (with Claude Sonnet 5)
**Time to Resolution:** ~50 minutes
