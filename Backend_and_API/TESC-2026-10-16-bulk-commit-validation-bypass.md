# Bulk commit accepted malformed client rows

**Date:** 2026-10-16
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The institution bulk-upload commit endpoint trusted the client-provided
preview structure too far. Directly submitted malformed rows could either
return a success response with zero imports or reach missing-field exceptions
and return HTTP 500.

## Symptoms
- A scholarship row with a negative amount and an unknown student returned
  HTTP 200 with `{"success": true, "imported": 0}`.
- A malformed student row missing required fields returned HTTP 500 with a
  `KeyError` for `first_name`.

## Environment Details
- **Server/Host:** `tesc-staging.zchpc.ac.zw`
- **Services Affected:** Institution bulk ingestion commit endpoint
- **Related Components:** `IngestionService.commit_upload`,
  `CommitUploadView`
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Ran negative bulk-upload cases against staging, including direct commit
requests that bypassed spreadsheet preview.

### 2. Root Cause Analysis
`commit_upload` skipped rows whose linked student did not exist and assumed
required keys were present before writing model records. It also skipped rows
already marked as validation errors, allowing a caller to receive a
success-shaped response without importing anything.

### 3. Key Findings
- Commit-time validation was incomplete for required fields and numeric values.
- Unknown linked students were silently ignored.
- Missing keys could raise `KeyError` and become HTTP 500.

## Root Cause
The commit layer treated preview output as trusted internal data rather than
untrusted client input, despite the endpoint accepting that data directly from
the institution frontend.

## Prevention / Rule
**Guardrail:** Bulk commit must validate row shape, required fields, formats,
numeric bounds, and relationship existence before any model write; invalid
client rows must return HTTP 400.

This closes the preview-bypass path and prevents malformed client payloads from
becoming silent no-ops or server errors.

## Solution

### Immediate Fix
- Added per-module required-field checks.
- Added commit-time date, PII, numeric, and date-order validation.
- Changed unknown student references from silent skips to explicit errors.
- Rejected rows marked invalid instead of returning success with zero imports.
- Converted `KeyError`, `TypeError`, and `ValueError` input failures to HTTP 400.

### Long-term Fix
Continue running the negative staging suite before user-training releases and
extend module-specific domain bounds as new upload fields are introduced.

## Verification
The initial edge-case run reproduced two failures. The fixes were applied
locally and require the staging deployment/retest to close verification.

## References
- `backend/academic/services/ingestion_service.py`
- `backend/academic/app_views/ingestion_views.py`
- `/tmp/tesc_staging_bulk_edge_cases.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
