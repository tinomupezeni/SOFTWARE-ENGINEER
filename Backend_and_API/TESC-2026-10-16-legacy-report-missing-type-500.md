# [TESC] Legacy Report Generation Returned 500 for Missing Report Type

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The legacy report-generation endpoint dereferenced `report_type.upper()` before validating the request. A malformed or empty request therefore produced HTTP 500 instead of a client-validation response.

## Symptoms
- `POST /api/v1/reports/generate/` with `{}` returned HTTP 500.
- The exception detail was `'NoneType' object has no attribute 'upper'`.

## Environment Details
- **Server/Host:** TESC staging Docker backend
- **Services Affected:** Legacy report generation
- **Related Components:** `backend/reports/services.py`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran a safe empty-payload probe for every pending report mutation endpoint.

### 2. Root Cause Analysis
Traced the request through `GenerateReportView` into `ReportService.generate_report`. The service formed the report name with `report_type.upper()` before checking that `report_type` existed.

```python
report_name = f"{report_type.upper()} Report - ..."
```

### 3. Key Findings
- The failure was deterministic.
- No database report was created before the exception.
- Other report endpoints returned controlled 400/200 responses for empty requests.

## Root Cause
Missing required-field validation in the legacy report service caused an unhandled `AttributeError`.

## Prevention / Rule
**Guardrail:** Every legacy API service that dereferences required request fields must validate required fields with DRF `ValidationError` before transformation or persistence.

This converts malformed client input into a stable 400 contract and prevents avoidable 500 responses.

## Solution

### Immediate Fix
Added `report_type` validation to `ReportService.generate_report` and redeployed the staging backend. The same empty request now returns HTTP 400 with `{"report_type": "This field is required."}`.

### Long-term Fix
Add a focused regression test for missing and blank `report_type`, then apply the same validation review to legacy report inputs.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `backend/reports/services.py`
- `/api/v1/reports/generate/`

---

**Resolved By:** Copilot
**Time to Resolution:** Same verification session
