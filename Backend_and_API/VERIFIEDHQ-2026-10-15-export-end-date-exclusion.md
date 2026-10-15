# VerifiedHQ Export Excluded Requested End Date

**Date:** 2026-10-15
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The attendance export treated `date_to` as midnight at the start of that day,
excluding all events occurring on the requested final date.

## Symptoms
- A request for `2026-10-01` through `2026-10-05` only included events before
  `2026-10-05 00:00:00`.
- Payroll exports could omit the last day's attendance.

## Environment Details
- **Server/Host:** FastAPI backend
- **Services Affected:** Payroll CSV/JSON export
- **Related Components:** `backend/app/routers/export.py`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the export date parsing and SQLAlchemy filter.

### 2. Root Cause Analysis
The query used `server_timestamp <= date_to` while `date_to` was parsed as
midnight. The intended API contract is an inclusive calendar-date range.

### 3. Key Findings
- The lower bound was correct.
- The upper bound needed to be exclusive midnight of the following day.

## Root Cause
Calendar dates were converted to timestamps without expanding the inclusive end
date to the next day's exclusive boundary.

## Prevention / Rule
**Guardrail:** Date-range exports must use `>= start_of_date` and `< start_of_day_after_end_date`.

This avoids precision-dependent end-of-day calculations and guarantees every
timestamp on the requested final date is included.

## Solution

### Immediate Fix
Add one day to the parsed end date and use a strict `<` comparison.

### Long-term Fix
Add a fixture containing an event late on `date_to` and assert it appears in the
export.

## Prevention
- [x] Add focused end-date regression test
- [ ] Add late-day fixture assertion
- [ ] Document payroll export date semantics

## References
- `backend/app/routers/export.py:37-54`
- `backend/tests/test_api_endpoints.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same review session
