# Mobile Home controller compile failure

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The new Flutter Home controller caught `ApiException` without importing the
class's defining API-client library, causing the mobile analyzer to fail.

## Symptoms
- `flutter analyze` reported `ApiException` was not a type in
  `home_controller.dart`.

## Environment Details
- **Server/Host:** Local development
- **Services Affected:** Flutter mobile client build
- **Related Components:** Riverpod Home controller, API client
- **Time First Observed:** 2026-11-06

## Investigation Steps

### 1. Initial Diagnosis
Ran the focused Flutter analyzer after wiring live Home data.

### 2. Root Cause Analysis
The controller imported `auth_controller.dart`, which itself imports the API
client, but Dart imports are not transitively visible to importing libraries.

### 3. Key Findings
- The route and serializer contract was correct.
- The failure was a compile-time import boundary error.
- Adding the direct import removed the analyzer failure.

## Root Cause
`ApiException` was referenced without a direct import of `api_client.dart`.

## Prevention / Rule
**Guardrail:** Run `flutter analyze` for every new feature slice before
committing mobile code.

The analyzer catches missing library boundaries immediately, before the issue
can reach a device build or integration test.

## Solution

### Immediate Fix
Added the direct `api_client.dart` import to
`mobile_flutter/lib/features/home/home_controller.dart`.

### Long-term Fix
Keep feature controllers importing the libraries that define their caught
exception and model types rather than relying on transitive imports.

## Prevention
- [x] Documentation updated
- [x] Code change completed
- [x] Analyzer regression check run

## References
- `mobile_flutter/lib/features/home/home_controller.dart`
- `mobile_flutter/lib/core/auth/api_client.dart`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
