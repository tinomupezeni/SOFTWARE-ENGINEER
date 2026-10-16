# VerifiedHQ Employee Device Registration Flow

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Type:** Feature / Workflow Improvement
**Status:** Completed

## Summary
Connected employee registration and personal-device enrollment into one admin
workflow. After HR registers an employee, the same page displays a one-time QR
pairing code and polls for consumption while the employee scans it from the
VerifiedHQ mobile app.

## Context / Trigger
The existing admin flow created the employee and then redirected the manager to
a separate device-pairing page. The requested Zimbabwe employer workflow is
employee-first: HR registers the person, then the employee immediately scans
their phone to bind it to that identity.

## Scope
Included:
- Returning the employee registration page with the generated personal-device
  pairing code.
- Rendering a QR code and manual fallback code on that page.
- Polling pairing status and showing successful device registration.
- Preserving the existing FastAPI pairing-token and Flutter scanner flow.

Excluded:
- Changing the cryptographic key generation or pairing API contract.
- Kiosk-specific assignment changes.
- Replacing the current QR rendering dependency.

## Method
Traced the Laravel employee controller, Blade form, FastAPI pairing endpoints,
Redis token lifecycle, and Flutter onboarding scanner. Reused the existing
one-time token flow rather than introducing a second registration protocol.

## Decisions & Findings
1. The backend already creates a one-time token bound to the new employee ID.
2. The Flutter app already scans the QR payload and sends its ECDSA public key
   to `/admin/devices/pair`.
3. The admin controller only needed to render the existing employee page after
   token generation instead of redirecting to `devices.pair`.
4. The page now confirms when the Redis token is consumed, giving HR immediate
   feedback that the phone is registered.

## Changes Made
- `admin/app/Http/Controllers/EmployeeController.php`
  - Renders `employees.create` with the employee and pairing token after
    successful personal-device registration.
- `admin/resources/views/employees/create.blade.php`
  - Added QR display, manual code, countdown, consumption polling, and
    completion state.
  - Updated copy and submit action to describe employee plus device registration.

## Verification
- `docker compose exec -T admin php artisan view:cache` passed.
- `docker compose exec -T admin php -l app/Http/Controllers/EmployeeController.php` passed.
- `GET /openapi.json` confirms `/admin/devices/pairing-token` is exposed.
- Existing Flutter onboarding scanner was inspected and remains compatible with
  the unchanged pairing-code payload.
- Dashboard remains available on port 8080 and backend on port 8010.

## Follow-ups / Deferred
- Perform a live end-to-end scan with a newly generated employee code.
- Add a Laravel feature test covering employee creation and pairing-code render.
- Replace the external QR script with a self-hosted asset for locked-down
  networks.
- Add explicit device status to the employee list.

## References
- `admin/app/Http/Controllers/EmployeeController.php`
- `admin/resources/views/employees/create.blade.php`
- `backend/app/routers/admin.py`
- `mobile/lib/screens/onboarding_screen.dart`
- `mobile/lib/services/api_service.dart`

---

**Completed By:** Copilot
**Duration:** Same debugging session
