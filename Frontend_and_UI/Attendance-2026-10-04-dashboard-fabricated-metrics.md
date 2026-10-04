# Admin overview dashboard shows fabricated KPIs and chart data

**Date:** 2026-10-04
**Project:** Attendance
**Environment:** Development
**Severity:** High
**Status:** Investigating

## Summary
`dashboard/index` renders hardcoded KPIs (142 active employees, 89 on-site, 3 suspicious) and static Chart.js datasets instead of querying the backend, presenting invented numbers as operational truth.

## Symptoms
- Overview page always shows the same numbers regardless of real ledger state.
- Charts (`attendanceChart`, `confidenceChart`) use inline static arrays (`[120,135,...]`, `[75,20,5]`).
- No loading, error, or empty state; a fresh empty database still reports 142 employees.

## Environment Details
- **Server/Host:** Laravel admin (`admin/`)
- **Services Affected:** `GET /dashboard`
- **Related Components:** `admin/resources/views/dashboard/index.blade.php:14,19,26,69,117`
- **Time First Observed:** 2026-10-04, during admin-dashboard audit

## Investigation Steps

### 1. Initial Diagnosis
Read `dashboard/index.blade.php`; found no backend calls, only inline literals.

### 2. Root Cause Analysis
The view was scaffolded with placeholder demo numbers and never wired to `/admin/ledger` or `/admin/employees`.

### 3. Key Findings
- Zero data flow from FastAPI to the dashboard view.
- Violates WORKING-PROCESS hard rule: never fabricate a displayed value; show honest `unavailable` when real data cannot resolve.

## Root Cause
Demo placeholders left in the request path with no live-data wiring and no gate requiring real aggregation before merge.

## Prevention / Rule
**Guardrail:** Code-review checklist item + CI grep gate rejecting hardcoded KPI literals in dashboard views unless sourced from a controller variable; dashboard PRs must include a screenshot against a seeded staging backend.

This closes the gap directly: the root cause is static numbers merged as if they were live data; a literal-data gate forces the wiring step.

## Solution

### Immediate Fix
Wire KPIs/charts to live `/admin/ledger` + `/admin/employees` aggregates; render honest empty/unavailable states when the backend is unreachable.

### Long-term Fix
Define dashboard SLO aggregates (guide 4/5a) and cache them server-side instead of computing inline in Blade.

## Prevention
- [ ] Configuration changes needed: none
- [ ] Monitoring/alerts to add: none
- [ ] Documentation to update: `docs/admin-dashboard-plan.md` Phase 2 (done)
- [ ] Code changes required: live dashboard aggregates; empty states

## Related Issues
- None known.

## References
- `admin/resources/views/dashboard/index.blade.php`
- `docs/admin-dashboard-plan.md`

---

**Resolved By:** N/A (flagged, not yet fixed)
**Time to Resolution:** N/A
