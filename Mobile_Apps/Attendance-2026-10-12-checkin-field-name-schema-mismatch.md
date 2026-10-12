# Every mobile clock-in fails 422, and the raw FastAPI validation error then crashes the check-in screen's layout

**Date:** 2026-10-12
**Project:** Attendance (Verified Attendance Platform)
**Environment:** Development
**Severity:** Critical — the app's core action ("Clock In") could never succeed against a real backend, and the failure manifested as a UI rendering crash, not just a clean error message
**Status:** Resolved

## Summary
`CheckInScreen._handleCheckInOut()` (mobile) builds its `/check-in` POST body
with fields `raw_telemetry_str`, `device_monotonic_ms`, and
`monotonic_delta_ms`. The backend's `CheckInRequest` schema
(`backend/app/schemas.py`) requires `raw_telemetry_hash` (a SHA-256 hex
digest, persisted to the immutable ledger's `raw_telemetry_hash` column)
and `hardware_monotonic_nanoseconds` (persisted to
`hardware_monotonic_nanoseconds`) — neither of which the mobile client ever
sent. Every check-in attempt was rejected by FastAPI/Pydantic with `422
Unprocessable Entity` before reaching any verification logic.

Compounding this, `ApiService.checkIn()`'s error handler
(`throw Exception(data['detail'])`) assumes `detail` is a short string, but
FastAPI's 422 responses return `detail` as a *list* of validation-error
objects. The stringified list (several hundred characters) was then written
directly into `_statusMessage` and rendered in a fixed, non-scrollable
`Column`, which overflowed by 963 pixels and crashed the layout (Flutter's
"yellow and black stripes" rendering error) the instant a user tapped
"Clock In" — turning a backend contract bug into a visible app crash rather
than a readable error.

## Symptoms
- Backend log: `POST /check-in HTTP/1.1" 422 Unprocessable Entity` on every
  attempt from the app.
- Flutter console, immediately after the biometric prompt succeeded:
  ```
  ══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═══...
  A RenderFlex overflowed by 963 pixels on the bottom.
  The relevant error-causing widget was:
    Column Column:file:///.../checkin_screen.dart:274:20
  ```
- Live-testing on a physical Android device: tapping "CLOCK IN" authenticated
  successfully, then the screen rendered the classic overflow stripes instead
  of a check-in confirmation or a legible error.

## Environment Details
- **Server/Host:** Local dev — FastAPI backend in Docker
  (`attendance-backend-1`), physical Android 15 device over ADB wireless
  debugging.
- **Services Affected:** `mobile/lib/screens/checkin_screen.dart`
  (`_handleCheckInOut`), `mobile/lib/services/api_service.dart` (`checkIn`).
- **Related Components:** `backend/app/schemas.py` (`CheckInRequest`),
  `backend/app/models.py` (`AttendanceEvent.raw_telemetry_hash`,
  `AttendanceEvent.hardware_monotonic_nanoseconds` — both `nullable=False`).
- **Time First Observed:** 2026-10-12, first live clock-in attempt against
  the freshly-stood-up backend this session.

## Investigation Steps

### 1. Initial Diagnosis
`flutter run` console showed a `RenderFlex overflowed by 963 pixels`
exception firing right after the biometric prompt succeeded on tapping
"CLOCK IN" — too large to be explained by the screen's normal fixed-height
content, pointing at an abnormally long string somewhere in that `Column`.

### 2. Root Cause Analysis
Checked `docker compose logs backend` for the actual network exchange:
```
POST /check-in/nonce HTTP/1.1" 200 OK
POST /check-in HTTP/1.1" 422 Unprocessable Entity
```
Replayed the exact payload shape the mobile client sends against the local
backend with `curl` to capture the full validation error body:
```json
{"detail": [
  {"type": "missing", "loc": ["body", "raw_telemetry_hash"], "msg": "Field required", ...},
  {"type": "missing", "loc": ["body", "hardware_monotonic_nanoseconds"], "msg": "Field required", ...}
]}
```
Compared against `backend/app/schemas.py`'s `CheckInRequest`:
```python
raw_telemetry_hash: str = Field(..., description="SHA-256 hash of telemetry")
hardware_monotonic_nanoseconds: int = Field(..., description="Device monotonic clock")
```
Both fields are also real, required, non-null columns on
`AttendanceEvent`/`VerificationEvidence` (`backend/app/models.py`) consumed
by `sensor_fusion.py`'s `evaluate_checkin()` — not dead schema fields, but
genuinely needed for the immutable audit ledger. The mobile client never
computed or sent either one; it sent `raw_telemetry_str` (accepted, but
optional and used only for signature verification) and `device_monotonic_ms`
/ `monotonic_delta_ms` (not part of the schema at all, silently ignored by
Pydantic).

On the client side, `ApiService.checkIn()`'s catch block does
`throw Exception(data['detail'])` assuming `detail` is a string; FastAPI's
422 `detail` here is a `List<Map>`, so the thrown exception's `toString()`
was the full Dart-formatted list — several hundred characters — which
`_handleCheckInOut`'s catch block wrote straight into `_statusMessage`,
rendered by a `Text` with no `maxLines`/scroll constraint inside a
fixed-size `Column`.

### 3. Key Findings
- This is the same root-cause class as the Club Zero
  `check-in`/`checkin` and `check_in_date`/`local_date` bugs: a mobile
  client's request shape hand-typed independently of the backend's actual
  Pydantic/FastAPI contract, with nothing to catch the two drifting apart.
- The UI crash was a second, independent bug layered on top of the first:
  even with a correct short error string, nothing bounded `_statusMessage`'s
  length before this fix.

## Root Cause
The mobile `/check-in` request body never matched the backend's
`CheckInRequest` schema (missing `raw_telemetry_hash` and
`hardware_monotonic_nanoseconds`, present-but-unused `device_monotonic_ms`
and `monotonic_delta_ms`), so the core "Clock In" action always failed
validation; and the client's generic error handler assumed FastAPI's
`detail` field is always a short string, letting an unbounded validation
error list reach an unconstrained `Text` widget and overflow the layout.

## Prevention / Rule
**Guardrail:** A contract/integration test that drives `ApiService.checkIn()`
against a real (or test-container) instance of the FastAPI backend — not a
mocked HTTP client — would have caught the missing required fields
immediately, the same guardrail called for in the Club Zero check-in
mismatches. Additionally, any `Text` displaying externally-sourced content
(server error messages, validation details) in a fixed, non-scrollable
layout should carry a `maxLines`/`overflow` bound as a standing rule for
this codebase, since the content's length is never under the client's
control.

Two independent bugs surfacing from the same single tap — a contract
mismatch and an unbounded error render — is a strong signal both guardrails
are worth adding rather than deferring again.

## Solution

### Immediate Fix
- `checkin_screen.dart`: compute `raw_telemetry_hash` as
  `sha256.convert(utf8.encode(telemetryJsonStr)).toString()` (using the
  already-imported `crypto` package) and
  `hardware_monotonic_nanoseconds` as `eventMonotonicMs * 1000000`; pass
  both into `_api.checkIn(...)`.
- `api_service.dart`: replaced `deviceMonotonicMs` with
  `rawTelemetryHash`/`hardwareMonotonicNanoseconds` in `checkIn()`'s
  signature and request body, matching `CheckInRequest` exactly.
- `checkin_screen.dart`: added `maxLines: 4` and
  `overflow: TextOverflow.ellipsis` to the `_statusMessage` `Text`, so any
  future oversized server error is truncated instead of overflowing the
  layout.
- Verified with `curl` against the running backend container: replaying the
  corrected payload shape no longer returns `422`; it now correctly reaches
  device-lookup logic and returns `401 Device not cryptographically bound`
  for a non-existent test device ID — confirming the schema mismatch is
  resolved. `flutter analyze` on both changed files shows no new issues.

### Long-term Fix
Not done in this pass: add a mobile-to-backend contract test (or generate
the Flutter request model from the backend's OpenAPI schema) so this class
of drift fails CI instead of surfacing as a live 422 plus a UI crash on a
physical device. Also worth addressing separately: the mobile "WORK
REMOTELY" button sends `event_type: "REMOTE"`, but
`AttendanceEventType` (`backend/app/models.py`) only defines `CHECK_IN`,
`CHECK_OUT`, and `OVERRIDE` — that action will also 422 and is not fixed in
this pass (see Related Issues / Follow-ups).

## Prevention
- [x] Fix the request field names/types in `api_service.dart` and
      `checkin_screen.dart`
- [x] Bound the status-message `Text` against oversized content
- [ ] Add a mobile-to-backend contract test for `/check-in`
- [ ] Decide how "WORK REMOTELY" should be modeled server-side (new enum
      value + migration, or mapped to an existing event type)

## Related Issues
- `Mobile_Apps/Attendance-2026-10-12-records-screen-nested-quote-build-break.md`
  and `Mobile_Apps/Attendance-2026-10-12-api-service-non-interpolating-error-string.md`
  — two earlier bugs found and fixed the same session while first bringing
  the app up on a physical device.

## References
- `mobile/lib/screens/checkin_screen.dart`
- `mobile/lib/services/api_service.dart`
- `backend/app/schemas.py` (`CheckInRequest`)
- `backend/app/models.py` (`AttendanceEvent`, `AttendanceEventType`)

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-10-12.
