# Records screen couldn't build at all — a nested single quote inside a single-quoted string terminated it early

**Date:** 2026-10-12
**Project:** Attendance (Verified Attendance Platform)
**Environment:** Development
**Severity:** Critical — the Flutter app could not be compiled or run on any device at all
**Status:** Resolved

## Summary
`lib/screens/records_screen.dart` failed to compile with `flutter run`.
The confidence-score label was written as a single-quoted string
containing an unescaped single quote from `record['confidence_score']`:
`'\${(record['confidence_score'] * 100).toInt()}%'`. The inner `'` closed
the outer string literal early, leaving
`confidence_score'] * 100).toInt()}%'` to be parsed as separate Dart
expressions — which the analyzer reported as "too many positional
arguments" to the `Text(...)` constructor. The leading `\$` (escaped,
non-interpolating) compounded the mistake, since even with matching
quotes it would not have interpolated the value at all. The app could not
be built on any platform until this was fixed.

## Symptoms
- `flutter run -d <device>` failed during `Running Gradle task
  'assembleDebug'` with:
  ```
  lib/screens/records_screen.dart:131:48: Error: Expected ',' before this.
  lib/screens/records_screen.dart:131:64: Error: Expected ',' before this.
  lib/screens/records_screen.dart:130:37: Error: Too many positional arguments: 1 allowed, but 3 found.
  ```
- Discovered live-testing a physical Android device connected over ADB
  wireless debugging — the build never reached install.

## Environment Details
- **Server/Host:** Local dev, physical Android 15 device (Samsung Galaxy
  S22 Ultra) connected via ADB wireless debugging.
- **Services Affected:** `mobile/lib/screens/records_screen.dart`
  (attendance records list, confidence-score label).
- **Time First Observed:** 2026-10-12, first attempt to run the mobile
  app on a physical device this session.

## Investigation Steps

### 1. Initial Diagnosis
`flutter run` failed before reaching install; read the compiler error
pointing at `records_screen.dart:131`.

### 2. Root Cause Analysis
```dart
// before
Text(
  '\${(record['confidence_score'] * 100).toInt()}%',
  ...
)
```
The outer string is single-quoted; `record['confidence_score']` also uses
single quotes for its map key. The `'` before `confidence_score` closes
the outer string literal at that point, so the parser sees a string
literal (`'\$`+`{(record'`), followed by bare tokens
(`confidence_score'] * 100).toInt()}%'`) as additional positional
arguments to `Text()`.

### 3. Key Findings
- This is a plain string-quoting mistake, not a logic bug — nothing about
  the actual confidence-score value or formatting was wrong once quoting
  was fixed.
- A sibling bug of the same class (escaped `\$` disabling interpolation,
  without the quote-nesting issue) was found in the same pass in
  `lib/services/api_service.dart` — see Related Issues.

## Root Cause
Single-quoted outer string literal containing an unescaped single-quoted
map key (`record['confidence_score']`), which terminated the string
early; compounded by an escaped `\$` that would have prevented
interpolation even with correct quoting.

## Prevention / Rule
**Guardrail:** Enable the `flutter_lints` analyzer (`analysis_options.yaml`,
already a dev dependency) as a required pre-build/CI gate — `flutter
analyze` catches this exact class of malformed-literal error statically,
before a Gradle build is ever attempted, and should run in CI
(`.github/workflows/`) for the mobile app the same way `backend.yml` and
`admin.yml` already gate the other two components.

This closes the gap because `flutter analyze` parses the same Dart
Kernel errors Gradle surfaced here, just seconds instead of minutes in,
and without needing a connected device.

## Solution

### Immediate Fix
Changed `records_screen.dart:131` to a double-quoted outer string with
proper interpolation:
```dart
"${(record['confidence_score'] * 100).toInt()}%"
```
Verified: `flutter run -d 192.168.60.116:42135` built and launched
successfully on the connected physical device after this fix (combined
with the `api_service.dart` fix in the related entry).

### Long-term Fix
Add a mobile CI workflow (`.github/workflows/mobile.yml`) running
`flutter analyze` and `flutter test`, mirroring the existing
`backend.yml`/`admin.yml` pattern. Not done in this pass.

## Prevention
- [x] Fix the malformed string literal
- [ ] Add `.github/workflows/mobile.yml` running `flutter analyze`
- [ ] Documentation to update

## Related Issues
- `Mobile_Apps/Attendance-2026-10-12-api-service-non-interpolating-error-string.md`
  — a sibling escaped-`$` bug found in the same session, same root cause
  class, different file.

## References
- `mobile/lib/screens/records_screen.dart`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-10-12.
