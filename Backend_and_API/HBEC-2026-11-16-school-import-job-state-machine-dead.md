# School student import: the job-status endpoint could never find a real job

**Date:** 2026-11-16
**Project:** HBEC
**Environment:** Development source review
**Severity:** Medium
**Status:** Resolved

## Summary
`SCHOOLS/schools_backend`'s `StudentImportJob` model implements a full
`pending → validating → ready/validation_failed → importing → completed/failed`
state machine, and `GET /api/v1/imports/<job_id>/status/` already polls it —
but `import_students_excel` processed every upload synchronously inline and
never created a `StudentImportJob` row at all. The polling endpoint was dead
code from the day it shipped: no job it could ever be asked about existed.
Separately, the frontend's drop-zone (`SCHOOLS/school_dashboard/src/routes/
import.tsx`) advertises `.xlsx` **and** `.csv`, but the backend rejected
anything that wasn't `.xlsx`.

## Symptoms
- `GET /imports/<job_id>/status/` had no real job to ever return, since
  nothing in the import path wrote to `StudentImportJob`.
- A `.csv` roster, which the file picker explicitly accepts
  (`accept=".xlsx,.csv"`), was rejected by the backend with a 400.

## Environment Details
- **Server/Host:** Local checkout.
- **Services Affected:** Backend and API.
- **Related Components:** `SCHOOLS/schools_backend/institutions/views.py`
  (`import_students_excel`, `import_job_status`),
  `SCHOOLS/schools_backend/institutions/models.py` (`StudentImportJob`),
  `SCHOOLS/school_dashboard/src/routes/import.tsx`.
- **Time First Observed:** 2026-11-16, during an audit requested ahead of
  adding an admin-operated equivalent of this import flow.

## Investigation Steps

### 1. Initial Diagnosis
Read the full import flow end to end (frontend upload call through the
Django view) while scoping a new admin-side bulk-import feature, to avoid
building a second surface on a broken foundation.

### 2. Root Cause Analysis
`import_students_excel` did all parsing, validation and student creation
inline inside the request/response cycle and returned a plain
`{created, errors}` JSON body — nothing in it referenced `StudentImportJob`
at any point. `import_job_status` was written against a model nothing else
in the codebase ever instantiated.

### 3. Key Findings
- The job model and its state machine were fully designed but never wired
  up — a frontend feature (status polling) silently depended on a backend
  path that didn't exist.
- The `.xlsx`-only check (`file.name.endswith(".xlsx")`) predates the
  dropzone copy that promises CSV support; the two drifted independently.

## Root Cause
The import endpoint was written once, synchronously, before (or without)
wiring it to the `StudentImportJob` model that was added alongside it —
and the file-extension check was never revisited when the frontend's
accepted-formats copy was later widened to include CSV.

## Prevention / Rule
**Guardrail:** A model that exists specifically to back a polling endpoint
needs a test asserting the write path populates it — `RunImportTests.
test_xlsx_import_creates_students_and_completes_the_job` in
`institutions/tests.py` now does this for the shared import service, so a
future refactor that stops writing to the job will fail CI instead of
shipping silently again.

This closes the exact gap here: nothing previously asserted that an import
actually produces a row the status endpoint can serve.

## Solution

### Immediate Fix
Extracted the import logic into `institutions/services/import_service.py`
(`run_import()`), which now creates a `StudentImportJob` up front and drives
it through every real state transition (`validating` → `ready`/
`validation_failed` → `importing` → `completed`/`failed`), updating
`total_rows`/`processed_rows` as it goes. `import_students_excel` is now a
thin wrapper around it. Also added `.csv` support (stdlib `csv` parsing
alongside the existing `openpyxl` path) so the backend matches what the
dropzone already claimed to accept.

### Long-term Fix
None needed beyond the above — the shared service is now also the one used
by the new admin-operated import endpoint, so both callers stay in sync by
construction rather than by convention.

## Prevention
- [x] Guardrail test added (`RunImportTests`).
- [ ] Replace the school dashboard's review-stage UI, which still shows
      seeded demo data instead of the job's real per-row validation —
      out of scope for this fix, flagged separately.

## Related Issues
- `HBEC-2026-11-16-school-import-predictable-passwords.md`
- `HBEC-2026-11-16-school-sync-missing-requests-dependency.md`

## References
- `SCHOOLS/schools_backend/institutions/services/import_service.py`
- `SCHOOLS/schools_backend/institutions/views.py`
- `SCHOOLS/schools_backend/institutions/tests.py`

---

**Resolved By:** Local code fix, 2026-11-16
**Time to Resolution:** Same session as discovery
