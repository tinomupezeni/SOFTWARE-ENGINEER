# VerifiedHQ Employee Duration Counter Removal

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The mobile check-in screen displayed a live elapsed-hours counter after an
employee clocked in. The employee requested that this monitoring-style display
be removed.

## Symptoms
- The check-in screen showed a continuously updating `HH:MM:SS` duration.
- The display made the employee feel continuously watched while on shift.

## Environment Details
- **Server/Host:** Samsung SM-S906U1 over wireless ADB
- **Services Affected:** Flutter employee check-in UI
- **Related Components:** Check-in state, local clock-in marker, periodic timer
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Traced the timer lifecycle in `checkin_screen.dart`, including state restore,
periodic updates, clock-out cleanup, and widget rendering.

### 2. Root Cause Analysis
The UI used a periodic timer based on `clock_in_time` solely to render elapsed
hours. That display was not required for check-in/out correctness.

### 3. Key Findings
- The persisted `clock_in_time` marker is still needed to know whether the
  employee should be offered check-out.
- The elapsed duration and periodic timer are presentation-only.
- Removing the counter does not remove attendance events or payroll export data.

## Root Cause
The employee UI exposed an unnecessary live duration calculation that was
coupled to, but not required by, check-in state.

## Prevention / Rule
**Guardrail:** Employee-facing attendance screens should show actionable
check-in state without live surveillance-style duration metrics unless the
product explicitly requires employee consent for that display.

This keeps operational state intact while respecting the requested employee
experience.

## Solution

### Immediate Fix
- Removed the periodic elapsed-time timer.
- Removed the `HH:MM:SS` employee-facing display.
- Preserved the internal clock-in marker used to restore checked-in state and
  permit clock-out.

### Long-term Fix
If employees need timesheets, provide a separate records/history view rather
than a continuously updating surveillance-style counter.

## Prevention
- [x] Remove live duration rendering
- [x] Preserve check-in/out state
- [ ] Add a UI test asserting no elapsed counter is rendered

## References
- `mobile/lib/screens/checkin_screen.dart`
- Related timestamp issue:
  `Backend_and_API/VERIFIEDHQ-2026-10-16-zimbabwe-time-display.md`

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session
