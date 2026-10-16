# VerifiedHQ Legacy Device Workplace Assignment

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
An employee device paired before workplace selection became mandatory remained
validly paired but had a `NULL` workplace assignment. The mobile app only had
its cached pairing metadata, so check-in stopped locally even though the
employee and device records existed.

## Symptoms
- The dashboard showed the employee identity, but check-in reported:
  `No workplace assigned to this device. Please re-pair it from the admin dashboard.`
- The device was present in `employee_devices` and had a valid ECDSA key.
- Its `assigned_workplace_id` was `NULL`.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** FastAPI check-in API and Flutter mobile client
- **Related Components:** Device pairing, workplace assignment, check-in request
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Queried the device records and reviewed recent pairing/check-in logs.

### 2. Root Cause Analysis
The device `ed840c00-ed5d-4e6f-9c5c-6808348e6108`, owned by `EMP778`, was
created by the earlier pairing flow with no workplace. The later registration
form fix only affected new pairing tokens and did not migrate existing devices.

### 3. Key Findings
- Pairing succeeded with `201 Created`.
- The device had a public key and employee owner.
- The workplace assignment was missing from the persisted device row.
- The mobile app treated its stale local cache as authoritative.

## Root Cause
The workplace requirement was introduced after a device had already been
paired, with no backfill or server-side fallback for legacy device metadata.

## Prevention / Rule
**Guardrail:** The check-in API must resolve an omitted workplace from the
persisted device assignment and reject only when both request and device
assignment are absent.

This preserves strict workplace integrity while allowing valid legacy devices
to recover after an administrator assigns their workplace.

## Solution

### Immediate Fix
- Assigned the existing `EMP778` device to the `ZINGSA` workplace.
- Made `workplace_id` optional at request validation time.
- Made the check-in route derive the workplace from the bound device.
- Removed the mobile local hard-stop when its cached workplace is empty.

### Long-term Fix
Provide an administrator device-assignment action and a migration/backfill
check for devices created before workplace assignment became mandatory.

## Prevention
- [x] Backfilled the affected device assignment
- [x] Added server-side workplace resolution
- [ ] Add device assignment/edit action in the dashboard
- [ ] Add a migration check for unassigned check-in devices
- [ ] Add an end-to-end legacy-device check-in test

## References
- `backend/app/schemas.py`
- `backend/app/routers/checkin.py`
- `mobile/lib/screens/checkin_screen.dart`
- `mobile/lib/services/api_service.dart`
- Device ID `ed840c00-ed5d-4e6f-9c5c-6808348e6108`
- Workplace ID `09aaaf27-c80c-42b2-a354-de538a4f2904`

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session
