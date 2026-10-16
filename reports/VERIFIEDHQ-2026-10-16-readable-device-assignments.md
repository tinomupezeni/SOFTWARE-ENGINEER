# Readable Device Assignments

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Type:** UX / Dashboard Cleanup
**Status:** Completed

## Summary
The device dashboard now shows employee names, employee codes, and workplace
names instead of requiring managers to interpret raw UUIDs.

## Context / Trigger
The device list displayed the owner employee UUID and workplace UUID, which
made it difficult to identify who owned a phone or where it was assigned.

## Scope
Included the FastAPI device-list response and Laravel device dashboard table.
The UUIDs remain available as secondary technical identifiers for support and
forensics.

## Method
Traced the device list API response into the Blade table, added left joins to
the employee and workplace tables, and preserved the existing IDs alongside
human-readable labels.

## Decisions & Findings
- Employee display: full name with employee code beneath it.
- Workplace display: workplace name with UUID beneath it.
- Unassigned devices display `Floating`.
- Employee-less devices display `Shared kiosk`.
- Device IDs remain abbreviated in the primary column.

## Changes Made
- `backend/app/routers/admin.py`: enrich `/admin/devices` with owner and
  workplace names/codes.
- `admin/resources/views/devices/index.blade.php`: render readable labels and
  retain IDs as secondary details.

## Verification
- `/admin/devices` returns `Tino`, `EMP778`, and `ZINGSA` for the repaired
  device.
- Blade view cache compilation passed.
- PHP syntax validation passed.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add a device detail page with reassignment and revocation actions.
- Consider hiding full UUIDs behind a tooltip or detail view for non-technical
  dashboard users.

## References
- `backend/app/routers/admin.py`
- `admin/resources/views/devices/index.blade.php`

---

**Completed By:** Copilot
**Duration:** Same debugging session
