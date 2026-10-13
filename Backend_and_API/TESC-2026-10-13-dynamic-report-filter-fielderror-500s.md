# Dynamic report filters 500 with FieldError across students/graduates/placements/scholarships/mobility

**Date:** 2026-10-13
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The ISEOP page's Download PDF button returned a 500 (`Failed to generate PDF`)
once an earlier `/v1` URL-prefix fix let the request actually reach the
backend. The root cause turned out to be two separate, compounding bugs in
`backend/reports/dynamic_service.py`'s `build_queryset()`, and an audit
across every `REPORT_SCHEMAS` field found the same class of bug silently
broke filtering on several other fields across five report types.

## Symptoms
- Browser console: `AxiosError: Request failed with status code 500` from
  `generatePDF`, triggered from the ISEOP page's "Download PDF" button.
- Backend traceback: `FieldError: Cannot resolve keyword 'is_iseop' into
  field` raised from inside `build_queryset()`.

## Environment Details
- **Server/Host:** tesc-staging VM, `tesc-backend-1` container.
- **Services Affected:** `backend` (Django/DRF), specifically
  `reports/dynamic_service.py`, `reports/dynamic_views.py`,
  `reports/pdf_generator.py`.
- **Related Components:** Students, Graduates, Staff, ISEOP pages' direct PDF
  download; the shared `ReportBuilder.tsx` dialog (STEM, Specialized/Critical
  Skills, Inclusivity, Possible Graduates, In-Country Transfers, Institution
  Detail); scholarships/mobility/placements stats pages.
- **Time First Observed:** 2026-10-13, immediately after a prior fix removed
  a 404 that had been masking this 500.

## Investigation Steps

### 1. Initial Diagnosis
Pulled the backend container's traceback for the exact failing request and
traced it to `dynamic_service.py:416` -> `build_queryset()` ->
`FieldError: Cannot resolve keyword 'is_iseop' into field`.

### 2. Root Cause Analysis
Read the custom-filter block for `report_type in ['students', 'graduates']`:
`is_iseop` was read via `filters.get('is_iseop')` instead of
`filters.pop(...)`, so after the custom block built its own
`iseop_profile__isnull` Q-filter, the key was *still* in `filters` and got
picked up a second time by the generic per-schema-field loop further down,
which tried `queryset.filter(is_iseop=True)` against a model with no such
column.

Per the user's instruction to check for the same issue elsewhere, wrote a
standalone script run via `manage.py shell` that iterates every filterable
field in every `REPORT_SCHEMAS` entry, resolves it through
`_get_relation_filter_key()`, and probes it against the real queryset to
catch `FieldError`.

```bash
ssh tesc-staging 'cd ~/TESC && docker compose -f docker-compose.prod.yml \
  exec backend python manage.py shell -c "exec(open(\"/app/audit_schema_fields.py\").read())"'
```

### 3. Key Findings
- `is_iseop` (students/graduates): left in `filters` after custom handling,
  reprocessed generically -> crash. `is_work_for_fees` had the identical
  latent shape but zero special-case handling at all.
- `_get_relation_filter_key()` — the table that remaps a schema display key
  (e.g. `program_level`) to its real ORM path (e.g. `selected_level`) — was
  only ever invoked inside the `elif field_type == 'relation':` branch of
  the generic loop, never for `'choice'`/`'boolean'`/`'string'` fields, even
  when those fields' schema key *also* doesn't match a real column.
- This silently broke: `program_level`, `program_category`,
  `disability_type`, `work_area` (students); `program_level`,
  `program_category`, `disability_type` (graduates); `gender`,
  `student_id_number`, `student_name` (placements, scholarships, mobility).
- `disability_type` had a correct mapping entry for `students` but was
  missing entirely from the `graduates` mapping dict.

## Root Cause
Two independent bugs compounding on the same code path:
1. `filters.get()` instead of `.pop()` let specially-handled virtual filter
   keys (`is_iseop`) leak into the generic per-field filter loop.
2. The generic loop only consulted the key-remapping table for fields typed
   `'relation'`, so any field declared `'choice'`/`'boolean'`/`'string'`
   whose schema key didn't match a real model column crashed instead of
   resolving correctly — even though the correct mapping already existed in
   the table for most of them.

## Prevention / Rule
**Guardrail:** a parametrized Django test that iterates every
`(report_type, field)` pair in `REPORT_SCHEMAS` where `filterable` is true,
calls `DynamicReportService.build_queryset(report_type, {field['key']: <a
representative value for field['type']>})`, and asserts it does not raise
`FieldError`. Wire this into CI so adding a new schema field with a
display-key that doesn't match its real ORM path, or adding a new
custom-filter special case without popping the key, fails the build instead
of surfacing as a 500 in production.

This closes the gap because both bugs in Root Cause only manifest at
queryset-build time with a specific filter value — a static schema-shape
check wouldn't catch either, but exercising `build_queryset()` itself with
one representative value per field would have caught both before merge.

## Solution

### Immediate Fix
In `backend/reports/dynamic_service.py`:
- `is_iseop` / `is_work_for_fees` now use `filters.pop(...)` with explicit
  True/False branches instead of `.get()`.
- The generic per-field loop now computes
  `actual_key = DynamicReportService._get_relation_filter_key(report_type, key)`
  unconditionally, for every field type, not just `'relation'`.
- Added the missing `'disability_type'` mapping entry to the `graduates`
  dict (mirroring the existing `students` entry), and `'work_area'` to
  `students`.

```bash
# Verified via a full REPORT_SCHEMAS field audit, then an end-to-end
# APIRequestFactory + force_authenticate call through the real
# DynamicReportGenerateView replicating the exact ISEOP PDF payload:
# {"report_type": "students", "filters": {"is_iseop": true}, ...} -> 200
```

### Long-term Fix
Add the CI guardrail described above so this class of bug is caught at
build time rather than requiring a user-reported 500 plus a manual
full-schema audit to surface it.

## Prevention
- [x] Configuration changes needed — none; this was a logic bug, not config.
- [ ] Monitoring/alerts to add — alert on 500s from `/v1/reports/*` endpoints.
- [ ] Documentation to update — none.
- [x] Code changes required — done (see Solution).

## Related Issues
- Preceded by: missing `/v1` URL prefix in frontend report services, which
  404'd before this bug could even surface (fixed same session, commit
  `93e4450`).

## References
- `backend/reports/dynamic_service.py`
- `backend/reports/schema_config.py`
- Commit: `44d2c07` on `staging`.

---

**Resolved By:** tinomupezeni (with Claude Sonnet 5)
**Time to Resolution:** ~1 hour
