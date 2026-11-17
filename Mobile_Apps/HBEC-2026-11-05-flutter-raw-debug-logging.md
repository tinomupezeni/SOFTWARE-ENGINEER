# Flutter entry point emits raw debug logs instead of structured telemetry

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development working tree
**Severity:** Medium
**Status:** Investigating

## Summary
`STUDENT/mobile_flutter/lib/main.dart` uses `debugPrint` for uncaught asynchronous errors and app lifecycle events. These records are raw text and lack the `trace_id`, `span_id`, and `service.name` fields required by the repository's production telemetry standard.

## Symptoms
- Async errors are printed as free-form text with an interpolated stack.
- Pause and resume messages are printed as free-form text.

## Environment Details
- **Server/Host:** Flutter client
- **Services Affected:** Mobile diagnostics
- **Related Components:** `STUDENT/mobile_flutter/lib/main.dart`, root `AGENTS.md`
- **Time First Observed:** 2026-11-05

## Investigation Steps

### 1. Initial Diagnosis
Read the Flutter entry point and root telemetry standard during handoff.

### 2. Root Cause Analysis
```bash
rg -n 'debugPrint|print\(' STUDENT/mobile_flutter/lib/main.dart
```

### 3. Key Findings
- `PlatformDispatcher.instance.onError` uses `debugPrint`.
- The lifecycle observer uses `debugPrint` for pause and resume.
- These calls bypass structured JSON logging and trace fields.

## Root Cause
The app entry point retained ad hoc diagnostics after the repository adopted a structured telemetry standard.

## Prevention / Rule
**Guardrail:** Add a Dart lint or CI source check that rejects `debugPrint` and `print` in production `lib/` code. This catches raw logging before a build is accepted.

## Solution

### Immediate Fix
None in this read-only handoff session.

### Long-term Fix
Route errors and lifecycle events through a Flutter-compatible JSON logger carrying the required trace and service fields; preserve stack details for exceptions.

## Prevention
- [ ] Monitoring/alerts to add
- [ ] Code changes required

## Related Issues
- None identified in this session.

## References
- `AGENTS.md`
- `STUDENT/mobile_flutter/docs/2026-08-18-flutter-mobile-parity-audit.md`

---

**Resolved By:** Pending
**Time to Resolution:** Pending
