# VerifiedHQ Personal Device Pairing Workplace Bypass

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The employee registration page required a workplace for new BYOD devices, but
the standalone device-registration page and FastAPI pairing-token endpoint
still allowed PERSONAL pairing requests without an employee or workplace.
This left a backend path that could recreate the legacy unassigned-device issue.

## Symptoms
- New employee registration was protected.
- Direct PERSONAL device pairing could still create a token with a null
  `assigned_workplace_id`.
- A phone paired through that path could reach check-in without a persisted
  workplace assignment.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** Laravel device registration and FastAPI pairing API
- **Related Components:** Device pairing, workplace assignment, BYOD onboarding
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Compared the employee registration flow with the standalone device
registration flow and inspected `PairingTokenRequest`.

### 2. Root Cause Analysis
`PairingTokenRequest.assigned_workplace_id` and the Laravel standalone form
were nullable for every device type. The employee page supplied a workplace,
but the shared pairing endpoint did not enforce the invariant for PERSONAL
devices.

### 3. Key Findings
- The employee flow already passed a selected workplace UUID.
- The standalone device form described workplace assignment as kiosk-only.
- The backend accepted a PERSONAL token without an owner or workplace.

## Root Cause
The workplace requirement existed only in one UI flow instead of at the
backend pairing boundary.

## Prevention / Rule
**Guardrail:** FastAPI must reject every PERSONAL pairing-token request unless
both `owner_employee_id` and `assigned_workplace_id` are present.

This makes the invariant independent of which dashboard route or future client
creates the pairing token.

## Solution

### Immediate Fix
- Added backend validation for PERSONAL pairing requests.
- Made employee and workplace required for PERSONAL devices in the Laravel
  standalone form.
- Updated the form labels and browser-required state.
- Preserved flexible kiosk assignment behavior.

### Long-term Fix
Add an integration test covering rejected PERSONAL requests and successful
PERSONAL requests with both required identifiers.

## Prevention
- [x] Enforce PERSONAL pairing requirements in FastAPI
- [x] Enforce PERSONAL pairing requirements in Laravel
- [x] Keep kiosk assignment behavior flexible
- [ ] Add automated pairing endpoint integration tests

## References
- `backend/app/routers/admin.py`
- `backend/app/schemas.py`
- `admin/app/Http/Controllers/DeviceController.php`
- `admin/resources/views/devices/create.blade.php`
- Validation result: missing-workplace PERSONAL request returns HTTP 400

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session
