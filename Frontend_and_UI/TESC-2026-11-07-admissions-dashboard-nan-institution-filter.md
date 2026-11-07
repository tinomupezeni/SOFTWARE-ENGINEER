# Admissions Dashboard NaN Values and Missing Institution Filter

**Date:** 2026-11-07
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Workaround Applied

## Summary
The staging Admissions dashboard displayed invalid `NaN`/empty values in the Top Program and Top Programs by Intake sections and offered no institution filter. The backend grouped current-intake students without excluding students whose program relation was null, while the frontend rendered response values without normalization or an institution query contract.

## Symptoms
- The Admissions page showed `NaN`/invalid program output for top-program data.
- Top Programs by Intake could render null or invalid labels and counts.
- Users could not scope admissions metrics to a single institution.

## Environment Details
- **Server/Host:** `tesc-prod` blue-green staging route
- **Services Affected:** Main frontend and analysis API
- **Related Components:** `frontend/src/pages/Admissions.tsx`, `frontend/src/services/analysis.services.ts`, `backend/analysis/views/admissions_views.py`
- **Time First Observed:** 2026-11-07

## Investigation Steps

### 1. Initial Diagnosis
Inspected the deployed Admissions bundle, local page component, API client, and `/api/analysis/admissions-stats/` implementation.

### 2. Root Cause Analysis
The API grouped current-intake records by `program__name` without filtering `program__isnull=False`. The frontend had no typed admissions response contract, passed no institution query parameter, and displayed raw text/numeric values.

```bash
curl -sS https://tesc-staging.zchpc.ac.zw/admissions
grep -R "admissions-stats\|top_programs" backend frontend/src
```

### 3. Key Findings
- Backend returned top-program groups that could contain null program names.
- Frontend had no institution selector or request parameter.
- Existing UI formatting allowed invalid values to reach cards and list rows.

## Root Cause
The backend response contract permitted incomplete program groups and the consumer assumed every program name and count was display-safe. The missing institution query contract meant the page could not request institution-scoped aggregates.

## Prevention / Rule
**Guardrail:** Admissions API contract tests must assert that top-program groups exclude null program relations and that an `institution_id` query produces institution-scoped aggregates; frontend tests must assert invalid display values are normalized.

This prevents both producer-side incomplete groups and consumer-side invalid rendering from silently reappearing.

## Solution

### Immediate Fix
- Added `institution_id` filtering to regular and ISEOP admissions aggregates.
- Excluded null program relations from top-program groups.
- Added typed admissions response/request handling and an institution selector.
- Normalized null, empty, and `NaN` labels/counts before rendering.

### Long-term Fix
Deploy the verified commit to the idle green color and perform authenticated staging behavioral verification before any cutover.

## Prevention
- [x] Frontend regression tests added for invalid values and institution query propagation
- [ ] Backend integration test with institution-scoped fixture data
- [ ] Authenticated staging user-journey verification
- [ ] Production cutover

## Related Issues
- None

## References
- `backend/analysis/views/admissions_views.py`
- `frontend/src/pages/Admissions.tsx`
- `frontend/src/services/analysis.services.ts`
- `frontend/src/pages/Admissions.test.tsx`
- `frontend/src/utils/admissions.ts`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
