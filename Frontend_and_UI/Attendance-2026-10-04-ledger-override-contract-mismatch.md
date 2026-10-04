# Admin ledger override is completely non-functional (form/controller/backend contract mismatch)

**Date:** 2026-10-04
**Project:** Attendance
**Environment:** Development
**Severity:** Critical
**Status:** Investigating

## Summary
The admin dashboard's Approve/Reject override flow can never succeed: the Blade form, the Laravel controller validation, and the FastAPI backend schema all disagree on field names, so every override submission fails validation before reaching the ledger.

## Symptoms
- Clicking Approve/Reject on `ledger.index` submits `original_event_id, employee_id, override_type`.
- `LedgerController@override` validates `target_event_id, new_status, reason` — request always 422s.
- Even if it passed, backend `POST /admin/ledger/override` expects `target_event_id, manager_id, new_status, reason`, and the view never sends `reason`; controller hardcodes `manager_id = admin-user-123` with no auth.

## Environment Details
- **Server/Host:** Laravel admin (`admin/`)
- **Services Affected:** `GET /ledger`, `POST /ledger/override` → FastAPI `POST /admin/ledger/override`
- **Related Components:** `admin/resources/views/ledger/index.blade.php:57-73`, `admin/app/Http/Controllers/LedgerController.php:40-56`, `backend/app/routers/admin.py:177-200`
- **Time First Observed:** 2026-10-04, during admin-dashboard audit

## Investigation Steps

### 1. Initial Diagnosis
Read the ledger view, controller, and backend override endpoint end to end following the Approve button.

### 2. Root Cause Analysis
Compared field names across the three layers; all three differ. Confirmed no request transformation in between.

### 3. Key Findings
- Three-layer contract mismatch: view (`original_event_id`/`override_type`) vs controller (`target_event_id`/`new_status`+`reason`) vs backend (`target_event_id`/`manager_id`/`new_status`/`reason`).
- No `reason` input exists in the UI, though backend and controller require it.
- No authentication: `manager_id` is a hardcoded string, violating SRS NFR-12 audit-trail requirement.
- View renders `OVERRIDE_APPROVED` badge but backend writes `event_type=OVERRIDE`, so overrides would not render as expected either.

## Root Cause
The override form and controller were built against different versions of the backend contract with no contract test or live smoke test exercising the full Approve path (an "Unfinished Pipe" per guide 19).

## Prevention / Rule
**Guardrail:** Add a consumer-driven contract test asserting the Blade form field names, controller validation rules, and backend `OverrideEvent` schema stay in sync, run in CI before merge.

This closes the gap directly: the root cause is three layers drifting on field names with nothing asserting they agree; a contract test makes that drift fail fast.

## Solution

### Immediate Fix
Align all three on `target_event_id, new_status, reason`; add reason textarea + status select to the view; wire `manager_id` to authenticated user instead of hardcoded string.

### Long-term Fix
Auth-gated override with before/after diff display; E2E smoke of approve+reject on staging per the dashboard plan Phase 0.

## Prevention
- [ ] Configuration changes needed: none
- [ ] Monitoring/alerts to add: none
- [ ] Documentation to update: `docs/admin-dashboard-plan.md` Phase 0 (done)
- [ ] Code changes required: align override contract; add contract test

## Related Issues
- None known.

## References
- `admin/resources/views/ledger/index.blade.php`
- `admin/app/Http/Controllers/LedgerController.php`
- `backend/app/routers/admin.py` (override_attendance)
- `docs/admin-dashboard-plan.md`

---

**Resolved By:** N/A (flagged, not yet fixed)
**Time to Resolution:** N/A
