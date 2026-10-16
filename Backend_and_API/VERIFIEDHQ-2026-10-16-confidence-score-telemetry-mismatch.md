# VerifiedHQ Confidence Score Telemetry Mismatch

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
An on-site check-in at ZINGSA received a 41.2% confidence score because the
mobile telemetry shape did not match the backend schema. GPS was collected but
sent under nested `gps` keys, so the backend stored null GPS evidence. The
confidence formula also used a sigmoid calibration that could never exceed
62.25%, even with perfect signals.

## Symptoms
- Event `0d7d91f1-9223-495f-8c69-3d9e52754f06` showed `41.2% Warn`.
- Ledger evidence showed `gps_lat`, `gps_lng`, and `gps_accuracy` as null.
- The check-in was physically performed at the assigned ZINGSA workplace.

## Environment Details
- **Server/Host:** Samsung SM-S906U1 over wireless ADB
- **Services Affected:** Flutter telemetry submission and FastAPI sensor fusion
- **Related Components:** GPS payload mapping, confidence calibration, geofence
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Inspected the ledger evidence and sensor-fusion implementation for the event.

### 2. Root Cause Analysis
The mobile client sent:

```json
{"gps":{"lat":...,"lng":...,"accuracy":...},"bssid_array":[],"device_attestation":"..."}
```

The backend schema expects flat fields such as `gps_latitude`,
`gps_longitude`, and `gps_accuracy_meters`. All location and network signals
therefore evaluated as missing. Separately, the formula applied
`sigmoid(weighted_sum - 0.5)`, whose maximum was `sigmoid(0.5) = 0.6225`.

### 3. Key Findings
- The 41.2% value matches only default liveness `0.5` and unknown-device
  integrity `0.3` contributing to the old formula.
- GPS collection itself succeeded on the phone.
- The configured 85% Verified threshold was unreachable under the old formula.

## Root Cause
The client/server telemetry contract drifted, and the score calibration was
mathematically inconsistent with the configured decision thresholds.

## Prevention / Rule
**Guardrail:** The mobile telemetry payload must use the `TelemetryData` field
names, and the confidence calculator must normalize over the evidence signals
present in a request before applying status thresholds.

This catches contract drift and prevents optional unavailable sensors from
artificially depressing otherwise strong attendance evidence.

## Solution

### Immediate Fix
- Mapped mobile GPS, BLE, and Wi-Fi fields to the backend schema.
- Changed active-signal scoring to a weighted average of available evidence.
- Treated a verified cryptographic device binding as strong device evidence when
  platform Play Integrity data is not yet available.
- Added workplace geofence/buffer validation using the stored PostGIS boundary.
- An on-site GPS + bound-device example now scores `0.90`.

### Long-term Fix
Add a client/server contract test using a real serialized mobile telemetry
fixture and expose signal-level score explanations in manager review.

## Prevention
- [x] Align mobile telemetry field names
- [x] Normalize score over available evidence
- [x] Validate GPS against workplace boundary
- [ ] Add serialized telemetry contract test
- [ ] Add score breakdown to ledger evidence

## References
- `mobile/lib/screens/checkin_screen.dart`
- `backend/app/sensor_fusion.py`
- `backend/app/schemas.py`
- Event `0d7d91f1-9223-495f-8c69-3d9e52754f06`
- ZINGSA workplace `09aaaf27-c80c-42b2-a354-de538a4f2904`

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session
