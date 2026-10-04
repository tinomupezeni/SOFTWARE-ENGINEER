# Workplace create page throws on Photon select (missing address input)

**Date:** 2026-10-04
**Project:** Attendance
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
Selecting a Photon search result on the workplace-create map runs `document.getElementById('address').value = label` unconditionally, but the form has no `#address` input, throwing a null-reference TypeError on every place search.

## Symptoms
- Map recenters and polygon draws, then JS throws on the missing element.
- Address is silently dropped (backend receives default `'Unknown Location'`).
- `autoBoundaryAlert` still shows, masking the error.

## Environment Details
- **Server/Host:** Laravel admin (`admin/`)
- **Services Affected:** `GET /workplaces/create`
- **Related Components:** `admin/resources/views/workplaces/create.blade.php:185-188` (JS), form inputs `name`, `uncertainty_buffer_meters`, `geojson_boundary`
- **Time First Observed:** 2026-10-04, during admin-dashboard audit

## Investigation Steps

### 1. Initial Diagnosis
Read `workplaces/create.blade.php` form vs its Photon `onclick` handler.

### 2. Root Cause Analysis
Handler assumes an `#address` field that was never added to the form; no null guard.

### 3. Key Findings
- One-line null dereference on the happy path of place search.
- Backend `store` accepts `address` optionally, so the failure is silent data loss, not a hard error.

## Root Cause
View JS and form markup drifted: search handler written for an address input that does not exist, with no guard and no test exercising place-select.

## Prevention / Rule
**Guardrail:** Null-guard DOM lookups in map views and add a smoke check that Photon-select populates `geojson_boundary` without console errors.

This closes the gap directly: the root cause is an unguarded `getElementById` on a non-existent node; the guard + smoke check makes it fail loudly in CI instead of silently in the browser.

## Solution

### Immediate Fix
Add hidden `address` input (or guard the lookup) and verify no console error on Photon select.

### Long-term Fix
Workplace create E2E: search → select → polygon present → submit enabled → stored workplace returned.

## Prevention
- [ ] Configuration changes needed: none
- [ ] Monitoring/alerts to add: none
- [ ] Documentation to update: `docs/admin-dashboard-plan.md` Phase 0 (done)
- [ ] Code changes required: add/guard address field; smoke test

## Related Issues
- None known.

## References
- `admin/resources/views/workplaces/create.blade.php`
- `docs/admin-dashboard-plan.md`

---

**Resolved By:** N/A (flagged, not yet fixed)
**Time to Resolution:** N/A
