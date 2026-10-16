# Local Time and Employee Privacy UX

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Type:** UX / Localization / Privacy Scope Decision
**Status:** Completed

## Summary
VerifiedHQ now presents attendance events in Zimbabwe local time while retaining
UTC as the storage and API interchange format. The employee mobile screen no
longer displays a live elapsed-hours counter, reducing a monitoring-style
experience without affecting check-in/out state or attendance records.

## Context / Trigger
A manager observed that a 09:04 Zimbabwe check-in appeared as 07:04 in the
dashboard. The employee also requested removal of the live clock-in duration
counter because it made them feel watched.

## Scope
Included the Laravel ledger list/detail timestamp presentation and Flutter
check-in screen duration UI. Excluded database timestamp storage, payroll
calculations, attendance event persistence, and manager-side verification data.

## Method
Traced timestamps from FastAPI responses to Blade rendering, verified the
timezone conversion independently, then traced the mobile timer lifecycle from
state restoration through periodic rendering and clock-out cleanup.

## Decisions & Findings
- Keep UTC for persistence and cross-service interchange.
- Display attendance timestamps in `Africa/Harare` for Zimbabwe users.
- Preserve an internal clock-in marker for checkout state.
- Remove the live employee-facing elapsed counter and periodic timer.
- Do not remove historical records or manager audit evidence.

## Changes Made
- `admin/resources/views/ledger/index.blade.php`: display Zimbabwe local time.
- `admin/resources/views/ledger/show.blade.php`: display local event time.
- `mobile/lib/screens/checkin_screen.dart`: remove live elapsed-duration UI and
  timer while retaining checked-in state.

## Verification
- Blade cache compilation passed.
- PHP syntax validation passed.
- `07:04 UTC` converted to `09:04 CAT`.
- Flutter analysis completed with existing repository lint/info findings and no
  new fatal analyzer error.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add automated tests for timezone presentation.
- Add a UI test ensuring the elapsed counter is absent.
- Consider a separate employee timesheet/history experience if requested.

## References
- `Backend_and_API/VERIFIEDHQ-2026-10-16-zimbabwe-time-display.md`
- `Frontend_and_UI/VERIFIEDHQ-2026-10-16-employee-duration-counter-removal.md`

---

**Completed By:** Copilot
**Duration:** Same debugging session
