# VerifiedHQ Check-in Workplace UUID Validation

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
Personal devices created through employee registration were paired without an
assigned workplace. The mobile app then substituted `UNKNOWN-WP` for
`workplace_id`, and FastAPI rejected the request with a `422 uuid_type`
validation error.

## Symptoms
- Phone check-in failed before reaching the verification pipeline.
- Backend returned `422 Unprocessable Entity`.
- The failing request came from the phone immediately after a successful nonce:
  `POST /check-in/nonce` → `200`, then `POST /check-in` → `422`.
- The user-facing error referred to `type=uuid_type`, `loc=body`,
  `workplace_id`.

## Environment Details
- **Server/Host:** Samsung SM-S906U1 over wireless ADB
- **Services Affected:** Flutter check-in and FastAPI check-in ingestion
- **Related Components:** Employee registration, device pairing, check-in schema
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Read the Android/Flutter logs and backend container logs while reproducing the
check-in action.

### 2. Root Cause Analysis
`EmployeeController` generated personal-device pairing tokens with
`assigned_workplace_id: null`. The Flutter pairing response therefore did not
store a workplace ID. `checkin_screen.dart` converted the missing value to the
literal string `UNKNOWN-WP`, while `CheckInRequest.workplace_id` is typed as a
UUID.

```text
POST /check-in/nonce HTTP/1.1 200 OK
POST /check-in HTTP/1.1 422 Unprocessable Entity
```

### 3. Key Findings
- The backend UUID validation is correct and prevented an invalid event from
  entering the ledger.
- The registration flow failed to collect the workplace context required by
  the attendance event model.
- The previous mobile fallback obscured the configuration problem and produced
  a misleading server validation error.

## Root Cause
The device-registration workflow allowed a personal device to be created without
the workplace required by the check-in contract.

## Prevention / Rule
**Guardrail:** Every check-in-capable device must receive a valid workplace UUID
at pairing time; mobile code must reject missing assignment locally instead of
serializing sentinel strings into typed API fields.

This keeps invalid configuration at the registration boundary and preserves the
server's strict UUID contract.

## Solution

### Immediate Fix
- Added an assigned-workplace selector to employee registration.
- Passed the selected workplace UUID into the personal-device pairing token.
- Replaced the `UNKNOWN-WP` mobile fallback with a clear re-pairing error.

### Long-term Fix
Add an end-to-end test that registers an employee/device, verifies the stored
workplace UUID, and submits a check-in payload.

## Prevention
- [x] Require workplace selection in employee device registration
- [x] Remove invalid `UNKNOWN-WP` request fallback
- [ ] Add pairing/check-in integration test
- [ ] Add device assignment visibility to the employee list

## References
- `backend/app/schemas.py:52-66`
- `admin/app/Http/Controllers/EmployeeController.php`
- `admin/resources/views/employees/create.blade.php`
- `mobile/lib/screens/checkin_screen.dart`
- Backend logs from 2026-10-16

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session
