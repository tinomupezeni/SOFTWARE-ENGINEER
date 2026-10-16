# VerifiedHQ Signature Verification Payload Mismatch

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
Valid mobile check-ins failed signature verification because Flutter signed the
documented canonical attendance payload, while FastAPI verified only the raw
telemetry JSON. The Flutter signing library also supplies a SHA-256 digest to
ECDSA, while the backend initially hashed the payload again.

## Symptoms
- The phone successfully obtained a check-in nonce.
- The check-in request returned HTTP `401 Unauthorized`.
- The mobile message reported `Signature verification failed`.
- No Android application crash occurred.

## Environment Details
- **Server/Host:** Samsung SM-S906U1 over wireless ADB
- **Services Affected:** Flutter check-in and FastAPI signature verification
- **Related Components:** ECDSA P-256, canonical payload construction, workplace fallback
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Compared the mobile payload construction with the backend verification call and
reviewed the live backend logs.

### 2. Root Cause Analysis
The mobile app signs:

```text
employee_code|workplace_id|device_id|event_type|nonce|telemetry_json
```

The backend passed only `telemetry_json` to the verifier. Separately, the
Flutter `ecdsa` package signs a SHA-256 digest supplied by the caller, whereas
the backend used the normal ECDSA-SHA256 mode, causing a double hash.

### 3. Key Findings
- `POST /check-in/nonce` returned `200`.
- `POST /check-in` returned `401`.
- The device key and pairing record were present.
- A standalone test reproduced and then verified the corrected Flutter
  prehashed canonical payload.

## Root Cause
The client and server did not implement the same cryptographic byte sequence or
hashing mode.

## Prevention / Rule
**Guardrail:** Keep one shared canonical payload contract and test both the
client-compatible prehashed ECDSA format and the server verifier in CI.

This catches payload-order, serialization, and double-hashing drift before a
valid device can be deployed.

## Solution

### Immediate Fix
- Backend now reconstructs the full canonical attendance payload.
- Backend verifies Flutter's SHA-256-prehashed ECDSA signature.
- Standard ECDSA-SHA256 verification remains supported for compatibility.
- Legacy paired devices with an empty local workplace cache may sign the exact
  empty-workplace form; the server still binds the event to the persisted
  device workplace.
- Removed a telemetry-span event call that caused the verifier helper to fail
  closed in the current local OpenTelemetry setup.

### Long-term Fix
Add an API integration test using a generated P-256 key and the exact Flutter
payload/signing format.

## Prevention
- [x] Align server verification with canonical payload
- [x] Support Flutter prehashed ECDSA signatures
- [x] Preserve persisted device workplace binding
- [ ] Add end-to-end cryptographic API regression test

## References
- `backend/app/crypto.py`
- `backend/app/routers/checkin.py`
- `mobile/lib/screens/checkin_screen.dart`
- `mobile/lib/services/crypto_service.dart`
- Backend log: `POST /check-in` → `401 Unauthorized`

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session
