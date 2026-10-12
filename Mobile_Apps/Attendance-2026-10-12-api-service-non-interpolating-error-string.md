# Check-in server-error messages would show the literal template text, not the actual HTTP status code

**Date:** 2026-10-12
**Project:** Attendance (Verified Attendance Platform)
**Environment:** Development
**Severity:** Medium — did not block the build, but destroyed diagnostic value of a user/dev-facing error message
**Status:** Resolved

## Summary
`ApiService` (`mobile/lib/services/api_service.dart`) throws a fallback
exception when a check-in request fails with a server error and no
`detail` field is present: `throw Exception('Server error:
\${e.response?.statusCode}');`. The leading backslash before `$` escapes
Dart's string interpolation, so the thrown message would literally read
`Server error: ${e.response?.statusCode}` instead of substituting the
real status code (e.g. `Server error: 500`). This did not break
compilation (unlike the sibling bug in `records_screen.dart`), but it
silently defeated the only diagnostic information in that error path.

## Symptoms
- No compiler error — this is a correctness/logic bug, not a syntax one.
- Any check-in failure that returns a server error without a `detail`
  field in the body would surface `Server error: ${e.response?.statusCode}`
  verbatim to whatever UI or log catches the exception, instead of the
  actual numeric status code.

## Environment Details
- **Server/Host:** Local dev, physical Android device.
- **Services Affected:** `mobile/lib/services/api_service.dart` (check-in
  error handling path).
- **Time First Observed:** 2026-10-12, found via a repo-wide grep for the
  same escaped-`$` pattern after finding and fixing the build-breaking
  sibling bug in `records_screen.dart`.

## Investigation Steps

### 1. Initial Diagnosis
After fixing the build-breaking nested-quote bug in `records_screen.dart`
(see related entry), grepped the mobile `lib/` tree for the same
escaped-dollar pattern (`\\\$`) to check for other instances before
re-running the build.

### 2. Root Cause Analysis
```dart
// before
throw Exception('Server error: \${e.response?.statusCode}');
```
The `\$` escape sequence in Dart produces a literal `$` character and
disables string interpolation for the `{...}` that follows it, so the
expression inside the braces is never evaluated — it's treated as plain
text.

### 3. Key Findings
- Same root-cause class (an escaped `$` meant to interpolate a value) as
  the build-breaking bug in `records_screen.dart`, but this one compiles
  fine since there was no nested-quote conflict — it just silently
  produces the wrong string at runtime, which is easy to miss without
  actually triggering the error path.

## Root Cause
Unnecessary backslash before `$` in a Dart string interpolation
expression, which disables interpolation and emits the literal
`${...}` template text instead of the evaluated value.

## Prevention / Rule
**Guardrail:** `flutter analyze` with `flutter_lints` enabled (already a
dev dependency; not yet wired into CI) flags this pattern
(`unnecessary_string_escapes` / related lints catch stray escapes in
string literals). Wiring `flutter analyze` into a mobile CI workflow — as
called for in the related `records_screen.dart` entry — would catch this
same class of mistake before merge, including non-build-breaking
instances like this one that are otherwise easy to miss.

## Solution

### Immediate Fix
Changed `api_service.dart` to a correctly interpolating string:
```dart
throw Exception('Server error: ${e.response?.statusCode}');
```
Verified alongside the `records_screen.dart` fix: `flutter run -d
192.168.60.116:42135` built and launched successfully on the connected
physical device.

### Long-term Fix
Add a mobile CI workflow (`.github/workflows/mobile.yml`) running
`flutter analyze`, per the related entry. Not done in this pass.

## Prevention
- [x] Fix the string interpolation
- [ ] Add `.github/workflows/mobile.yml` running `flutter analyze`
- [ ] Documentation to update

## Related Issues
- `Mobile_Apps/Attendance-2026-10-12-records-screen-nested-quote-build-break.md`
  — the build-breaking sibling bug found first in the same session, same
  root-cause class (escaped `$` disabling interpolation).

## References
- `mobile/lib/services/api_service.dart`

---

**Resolved By:** Claude (Sonnet 5), found and fixed same-session for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-10-12.
