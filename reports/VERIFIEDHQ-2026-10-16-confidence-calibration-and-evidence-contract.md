# Confidence Calibration and Evidence Contract

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Type:** Refactor / Reliability / Scoring Decision
**Status:** Completed

## Summary
VerifiedHQ confidence scoring was corrected so valid on-site evidence is not
discarded due to telemetry field drift or an unreachable sigmoid calibration.
GPS is now delivered in the backend schema shape, validated against the
workplace boundary, and scored with cryptographic device evidence.

## Context / Trigger
An event performed at ZINGSA received 41.2% confidence. Investigation showed
the GPS was not stored and the configured 85% verification threshold could never
be reached by the existing formula.

## Scope
Included mobile telemetry serialization and backend sensor-fusion calibration.
Excluded biometric enrollment, Play Integrity integration, and BLE/Wi-Fi
hardware capture, which remain future evidence sources.

## Method
Compared the stored event evidence with the Pydantic telemetry contract, traced
each signal through `evaluate_checkin`, calculated the old formula's maximum,
then implemented and tested an available-evidence weighted score with geofence
validation.

## Decisions & Findings
- Optional unavailable sensors should not count as zero when they were not
  collected.
- GPS coordinates must be inside the workplace boundary or its uncertainty
  buffer to contribute positively.
- A verified ECDSA-bound device is meaningful integrity evidence even before
  Play Integrity is integrated.
- The old sigmoid calibration was removed from request-time active scoring;
  legacy unit-test behavior remains covered when no active signal set is passed.
- A valid on-site GPS + bound device scores 90% before additional biometric,
  liveness, BLE, or Wi-Fi evidence.

## Changes Made
- `mobile/lib/screens/checkin_screen.dart`: send flat `TelemetryData` fields.
- `backend/app/sensor_fusion.py`: active-signal normalization, cryptographic
  binding evidence, and PostGIS workplace-buffer validation.

## Verification
- Sensor-fusion suite: `31 passed`.
- Score probe: on-site GPS + bound device = `0.9000`.
- Flutter analysis completed with existing repository lint/info findings.
- Python compilation and whitespace validation passed.

## Follow-ups / Deferred
- Add serialized client/server telemetry contract tests.
- Add score breakdown to evidence records and manager review.
- Integrate platform Play Integrity and actual BLE/Wi-Fi capture.
- The old immutable event remains at 41.2%; new check-ins use the corrected
  scoring path.

## References
- `Backend_and_API/VERIFIEDHQ-2026-10-16-confidence-score-telemetry-mismatch.md`
- `backend/app/sensor_fusion.py`
- `mobile/lib/screens/checkin_screen.dart`

---

**Completed By:** Copilot
**Duration:** Same debugging session
