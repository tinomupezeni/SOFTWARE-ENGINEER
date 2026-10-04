# Check-in endpoint prints the full reconstructed payload (incl. employee code, GPS telemetry) to stdout on every request

**Date:** 2026-10-04
**Project:** Attendance
**Environment:** Development (present in code that will ship to Production as-is)
**Severity:** Medium
**Status:** Investigating

## Summary
`POST /check-in` in `backend/app/main.py` reconstructs the exact string the
mobile client signed (employee code, workplace id, device id, event type,
nonce, and the full telemetry JSON — which includes raw GPS lat/lng,
accuracy, and BSSID array) and writes it to stdout via a bare `print()` on
every single check-in request, verified or not. This bypasses the
project's own structured OpenTelemetry/JSON logging (`app/telemetry.py`)
and puts PII + precise location data into unstructured container logs
with no retention/redaction policy.

## Symptoms
- No user-visible symptom; found during a code read, not an incident.
- Every call to `/check-in` emits a line like:
  `DEBUG BACKEND RECONSTRUCTED PAYLOAD: EMP001|<workplace-uuid>|<device-uuid>|CHECK_IN|<nonce>|{"gps":{"lat":...,"lng":...,"accuracy":...},...}`

## Environment Details
- **Server/Host:** FastAPI ingestion service (`backend/app/main.py`)
- **Services Affected:** `/check-in` endpoint, container stdout / log aggregation
- **Related Components:** `backend/app/main.py:98`, `backend/app/telemetry.py` (structured logger that was bypassed)
- **Time First Observed:** 2026-10-04, during a full codebase read

## Investigation Steps

### 1. Initial Diagnosis
Read `submit_check_in` in `backend/app/main.py` end to end to understand
the check-in flow (nonce validation → device lookup → signature
verification → sensor fusion → persistence).

### 2. Root Cause Analysis
Line 98 contains a leftover debugging statement:

```python
payload_str = f"{request.employee_code}|{wp_id_str}|{str(request.device_id)}|{request.event_type}|{request.nonce}|{telemetry_json}"
print(f"DEBUG BACKEND RECONSTRUCTED PAYLOAD: {payload_str}", flush=True)
```

It was almost certainly added to debug the client/server payload-string
mismatch during ECDSA signature verification development, and never
removed. It runs unconditionally, with `flush=True`, on the hot path of
every check-in, not gated by a debug flag or log level.

### 3. Key Findings
- Logs PII (employee code) and precise location (GPS lat/lng, accuracy) in plaintext to stdout.
- Bypasses the app's own OpenTelemetry-instrumented structured logger, so it won't carry trace context or respect any log-level/redaction config that logger has.
- Runs on every request regardless of verification outcome, so volume scales with check-in traffic.

## Root Cause
A debug `print()` statement added while developing the ECDSA signature
verification logic (to compare the client-signed string against the
server-reconstructed one) was left in the request path instead of being
removed or converted to a gated debug-level structured log.

## Prevention / Rule
**Guardrail:** Add a lint/CI check (e.g. a `ruff`/custom AST rule, since
the project already uses `ruff`/`mypy` per the README) that fails the
build on any bare `print(` call inside `backend/app/**`, forcing all
output through the structured `logger` in `app/telemetry.py`.

This closes the gap directly: the root cause is a stray `print()` that
skipped code review/linting because nothing currently forbids `print()`
in the backend; a dedicated lint rule makes this class of leftover-debug
output impossible to merge again.

## Solution

### Immediate Fix
Not applied this session (found during a read-only codebase review, no
changes made). Recommended immediate fix: delete the `print(...)` line at
`backend/app/main.py:98`, or replace it with
`logger.debug("reconstructed payload", extra={"payload_hash": ...})` that
logs a hash rather than the raw PII/telemetry string.

### Long-term Fix
Add the `print()`-forbidding lint rule described above to CI so this
class of leftover debug statement is caught before merge, and audit the
rest of `backend/app` for other stray `print()` calls.

## Prevention
- [ ] Configuration changes needed: none
- [ ] Monitoring/alerts to add: none
- [ ] Documentation to update: none
- [x] Code changes required: remove/replace the `print()` at `main.py:98`; add lint rule banning `print()` in `backend/app`

## Related Issues
- None known.

## References
- `backend/app/main.py` (submit_check_in)
- `backend/app/telemetry.py` (structured logger that should have been used instead)

---

**Resolved By:** N/A (flagged, not yet fixed)
**Time to Resolution:** N/A
