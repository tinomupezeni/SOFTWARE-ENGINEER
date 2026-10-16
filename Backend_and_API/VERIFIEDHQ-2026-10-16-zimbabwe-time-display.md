# VerifiedHQ Zimbabwe Time Display

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Attendance events were displayed in UTC in the dashboard, making Zimbabwe
check-ins appear two hours earlier than the local event time.

## Symptoms
- A check-in made at approximately 09:04 Zimbabwe time appeared as `07:04`.
- The ledger header explicitly showed `Time (UTC)`, exposing the storage
  timezone instead of the user-facing local timezone.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** Laravel attendance ledger
- **Related Components:** Carbon timestamp formatting, Africa/Harare display
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Compared the stored API timestamp with the dashboard rendering and confirmed
the API returned an ISO timestamp in UTC.

### 2. Root Cause Analysis
The ledger view parsed `server_timestamp` and formatted it without changing its
timezone. Storage remained correct in UTC, but presentation omitted the
`Africa/Harare` conversion.

### 3. Key Findings
- UTC storage is appropriate for ordering, exports, and cross-system integrity.
- The dashboard is used by Zimbabwean managers and must display local time.
- Carbon supports the required timezone conversion without changing persisted
  event data.

## Root Cause
The presentation layer treated a UTC storage timestamp as if it were already in
the user's local timezone.

## Prevention / Rule
**Guardrail:** User-facing attendance timestamps must explicitly convert to
`Africa/Harare`; UTC remains the storage and API interchange timezone.

This prevents a correct UTC record from being misread as an incorrect local
attendance time.

## Solution

### Immediate Fix
- Changed the ledger list to display `Time (Zimbabwe)`.
- Converted ledger timestamps to `Africa/Harare`.
- Converted event evidence detail timestamps to Zimbabwe local time.

### Long-term Fix
Apply the same display helper to any future attendance-facing timestamp view
and add a timezone presentation test.

## Prevention
- [x] Convert dashboard event timestamps to Africa/Harare
- [x] Keep UTC storage unchanged
- [ ] Add automated presentation test

## References
- `admin/resources/views/ledger/index.blade.php`
- `admin/resources/views/ledger/show.blade.php`
- Verification: `2026-10-16T07:04:00Z` renders as `Oct 16, 09:04 CAT`

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session
