# Offline monotonic-clock anti-fraud design (ADR-0002) is not actually implemented — server stores its own monotonic clock, never the device's

**Date:** 2026-10-04
**Project:** Attendance
**Environment:** Development
**Severity:** High
**Status:** Investigating

## Summary
The platform's documented anti-fraud design (`docs/adr/0002-monotonic-clocks-for-offline.md`,
`ARCHITECTURE.md`'s "Monotonic Clock Anchoring") is: when a device is
offline, it tracks elapsed time via its own unmodifiable hardware
monotonic clock, and the backend uses the client-reported monotonic delta
to recompute the true historical timestamp, "bypassing any OS-level clock
manipulations." The backend code that is supposed to persist this
hardware monotonic value instead records the *server's own* monotonic
clock reading at commit time, which is meaningless for fraud detection —
it does not use, or even read, anything from the device. The only part
that is implemented is subtracting the client-sent `monotonic_delta_ms`
from the server wall-clock `utcnow()`, which does not require, and does
not benefit from, a monotonic clock at all.

## Symptoms
- No user-visible symptom yet; found during a code read, not an incident.
- `attendance_events.hardware_monotonic_time` in the database will always
  reflect the backend process's own `time.monotonic_ns()` (nanoseconds
  since *that process* started), not anything tied to the employee's
  device — so it cannot be used later to detect device clock tampering or
  cross-check offline durations, despite the column's name and the ADR's
  stated purpose.

## Environment Details
- **Server/Host:** FastAPI ingestion service, sensor fusion module
- **Services Affected:** `/check-in` offline-sync path, `attendance_events.hardware_monotonic_time` column, any future audit/dispute relying on this field
- **Related Components:** `backend/app/sensor_fusion.py:94-117` (`_create_event`), `backend/migrations/001_initial_schema.sql` (`hardware_monotonic_time BIGINT NOT NULL`), `docs/adr/0002-monotonic-clocks-for-offline.md`
- **Time First Observed:** 2026-10-04, during a full codebase read

## Investigation Steps

### 1. Initial Diagnosis
Read ADR-0002 and `ARCHITECTURE.md`'s "Monotonic Clock Anchoring" claim,
then traced the actual implementation in `sensor_fusion.py::_create_event`.

### 2. Root Cause Analysis
```python
# Offline Monotonic Sync Calculation (Sprint 3)
# The client sends monotonic_delta_ms (CurrentMonotonic - EventMonotonic)
from datetime import datetime, timedelta
server_now = datetime.utcnow()
true_event_timestamp = server_now - timedelta(milliseconds=request.monotonic_delta_ms)

hardware_monotonic = int(time.monotonic_ns())  # Fallback or store actual if sent
```
The comment `# Fallback or store actual if sent` admits the intended
behavior (store the device's actual monotonic reading when the client
sends one) was never wired up — `request.monotonic_delta_ms` is used only
to offset the server wall clock, and the value actually persisted to
`hardware_monotonic_time` is always the server's own `time.monotonic_ns()`,
a number that resets on every backend process restart and has no
relationship to the employee's device.

### 3. Key Findings
- The device-side hardware monotonic reading is never read from the request or persisted anywhere.
- The stored `hardware_monotonic_time` column is unusable for its documented purpose (detecting OS-level clock manipulation / verifying offline duration against device state).
- The timestamp correction that *is* implemented (`server_now - monotonic_delta_ms`) only requires the client to self-report an elapsed-time delta; nothing in the current backend cross-checks that delta against anything tamper-resistant, so a malicious client can still claim an arbitrary elapsed offline duration — exactly the fraud vector ADR-0002 says this design prevents.

## Root Cause
The Sprint 3 offline-sync feature was implemented partially: the
timestamp-shifting arithmetic was built, but the actual anti-fraud
anchor — persisting and later validating the device's own monotonic
clock value(s) — was left as a TODO (per the inline comment) and never
completed, while the schema/architecture docs already describe it as done.

## Prevention / Rule
**Guardrail:** Add a schema/code-level invariant check (e.g. a unit test
asserting `AttendanceEvent.hardware_monotonic_time` for any event carrying
a non-zero `monotonic_delta_ms` cannot equal a freshly-sampled server
`time.monotonic_ns()` value) so a regression or an incomplete feature like
this one fails CI instead of silently shipping as "done" because the
column is populated with *some* number.

This targets the actual root cause: the bug wasn't a crash, it was a
column that looks filled-in and correct but carries the wrong clock's
value — a test asserting the value's provenance (device-reported, not
server-sampled) is the only check that would have caught it.

## Solution

### Immediate Fix
Not applied this session (read-only review). Needs product/engineering
input on scope: requires (1) the mobile client to actually send its
device monotonic reading(s) (`CheckInRequest` currently only carries
`monotonic_delta_ms`, not the raw device monotonic value), (2) a schema/
request decision on what "actual" value to store, and (3) backend logic
to persist and later validate it. This is more than a one-line fix.

### Long-term Fix
Either complete the feature as ADR-0002 describes it (persist the
device's real monotonic reading and validate the offline delta against
it), or update ADR-0002/ARCHITECTURE.md to accurately describe the
weaker guarantee currently implemented (client-reported elapsed-time
offset, not a tamper-resistant monotonic anchor) so documentation and
code stop disagreeing.

## Prevention
- [ ] Configuration changes needed: none
- [ ] Monitoring/alerts to add: none
- [x] Documentation to update: ADR-0002 / ARCHITECTURE.md vs. actual behavior, or implement the missing piece
- [x] Code changes required: wire device monotonic value through `CheckInRequest` → `_create_event`, or descope the doc

## Related Issues
- None known.

## References
- `docs/adr/0002-monotonic-clocks-for-offline.md`
- `ARCHITECTURE.md` ("Monotonic Clock Anchoring")
- `backend/app/sensor_fusion.py`

---

**Resolved By:** N/A (flagged, not yet fixed)
**Time to Resolution:** N/A
