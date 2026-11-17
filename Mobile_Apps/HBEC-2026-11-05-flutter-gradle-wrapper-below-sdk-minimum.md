# Flutter Gradle Wrapper Below SDK Minimum

**Date:** 2026-11-05
**Project:** HBEC
**Environment:** Development Android build
**Severity:** High
**Status:** Resolved locally; debug APK build passed

## Summary
The student Flutter Android wrapper pinned Gradle 8.13, while the installed Flutter SDK requires at least 8.14. The APK build failed before compiling the changed mobile practice code.

## Symptoms
- `flutter build apk --debug` failed applying `dev.flutter.flutter-gradle-plugin`.
- Flutter reported Gradle 8.13.0 below its minimum supported 8.14.0.

## Environment Details
- **Server/Host:** Local HBEC checkout
- **Services Affected:** Student Flutter Android build
- **Related Components:** `android/gradle/wrapper/gradle-wrapper.properties`
- **Time First Observed:** 2026-11-05

## Investigation Steps

### 1. Initial Diagnosis
Ran an APK build after adding the WebView practice route.

### 2. Root Cause Analysis
Compared the Flutter build error with the Gradle wrapper distribution URL.

```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://api.hbca.tech/api --dart-define=WEB_APP_URL=https://student.hbca.tech
cat android/gradle/wrapper/gradle-wrapper.properties
```

### 3. Key Findings
- Wrapper used `gradle-8.13-all.zip`.
- Flutter plugin required Gradle 8.14 or newer.
- Gradle 8.14 was available in the local wrapper cache.

## Root Cause
The Gradle wrapper version lagged behind the Flutter SDK requirement.

## Prevention / Rule
**Guardrail:** Run `flutter build apk --debug` in CI whenever the Flutter SDK or Android Gradle configuration changes.

This catches wrapper/plugin incompatibility before relying on a stale local APK.

## Solution

### Immediate Fix
Updated the wrapper distribution URL to `gradle-8.14-bin.zip`. The configured debug APK then built successfully.

### Long-term Fix
Keep the wrapper version aligned with Flutter's supported range in the build gate.

## Prevention
- [x] Code changes required
- [ ] Monitoring/alerts to add
- [ ] Configuration changes needed
- [ ] Documentation to update

## Related Issues
- None

## References
- Flutter Gradle plugin build error, 2026-11-05

---

**Resolved By:** Codex
**Time to Resolution:** Same session
