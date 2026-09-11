# Android 15 Crash on Every Keyboard Focus — Forced Old androidx.core Version

**Date:** 2026-08-19
**Project:** HBEC (mobile_flutter)
**Environment:** Production (real device)
**Severity:** Critical
**Status:** Resolved

## Summary
The Flutter student app crashed every single time a text field was focused (bringing up the on-screen keyboard) on the user's real Android 15 device. The app was otherwise stable — this reproduced 100% of the time on this OS version, on any screen with a text input.

## Symptoms
- User: "ITS CRUSHING... whne you try to focus n an input to bring up the keyboard"
- Crash was instant and total on keyboard focus, on a real Samsung Galaxy S22+ running Android 15 (API 35)
- No crash on the same build in a lower-API emulator, which initially pointed investigation the wrong way

## Environment Details
- **Server/Host:** User's own physical Android device (wireless ADB debugging session)
- **Services Affected:** `mobile_flutter` app, all screens with text input
- **Related Components:** `android/app/src/main/kotlin/.../MainActivity.kt`, `android/build.gradle.kts`
- **Time First Observed:** 2026-08-19, reported live during a debugging session

## Investigation Steps

### 1. Initial Diagnosis
First hypothesis was edge-to-edge/`adjustResize` window inset handling, since that's a common Android 15 keyboard-related crash class. Checked `MainActivity.kt` and found `WindowCompat.setDecorFitsSystemWindows(window, false)` already correctly in place from an earlier (Aug 2) fix for that exact symptom class — so this was a red herring, not the actual cause.
Set up Firebase Test Lab (Robo test) first, but a Robo test can't authenticate past login without provided credentials, so "Passed" there was inconclusive — it likely never reached a real text field. Pivoted to direct on-device investigation via wireless ADB (`adb pair`/`adb connect`) so real logcat output during a real crash could be captured.

### 2. Root Cause Analysis
Live logcat on the real device during the crash showed:
```
java.lang.NoSuchMethodError: ... EditorInfoCompat.setStylusHandwritingEnabled ...
```
Flutter's `TextInputPlugin` calls this AndroidX Core API on focus. `android/build.gradle.kts` had a `resolutionStrategy.force("androidx.core:core:1.9.0")` (and `core-ktx:1.9.0`) pinning the whole project to a version predating that method's existence — traced via `git log -S` to commit `ae54bf9` (2026-07-13, no explanatory message).

### 3. Key Findings
- The forced version pin had nothing to do with the actual edge-to-edge fix already in place — it was an unrelated, separate landmine
- `git log -S` (pickaxe search) was what actually found the introducing commit, since there was no commit message context to go on
- Verified fixed live: after removing the force block and rebuilding, 60 seconds of logcat with repeated input-field taps showed zero crashes and the same process PID stayed alive throughout

## Root Cause
`android/build.gradle.kts` force-pinned `androidx.core`/`core-ktx` to `1.9.0` project-wide. Flutter's `TextInputPlugin` calls `EditorInfoCompat.setStylusHandwritingEnabled`, an API that doesn't exist in that pinned version, so any Android 15 device (whose Flutter engine build expects a newer AndroidX Core) crashed with `NoSuchMethodError` the instant a text field was focused.

## Solution

### Immediate Fix
Removed the `resolutionStrategy.force(...)` block from `android/build.gradle.kts` entirely, leaving only the plain `allprojects { repositories { google(); mavenCentral() } }`.

### Long-term Fix
Committed as `eddd691` (`fix(mobile): stop forcing an old androidx.core version`). No replacement pin was added — letting Gradle resolve the version normally is the actual fix, not swapping in a different fixed version that could rot the same way.

## Prevention
- [ ] Note in `mobile_flutter`'s own CLAUDE.md: never force-pin `androidx.core`/`core-ktx` without a specific documented reason, since Flutter's own engine expects to move with it
- [x] Verified live on the real device that triggered the report, not just in an emulator

## References
- `git log -S "androidx.core:core:1.9.0"` on `android/build.gradle.kts`

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~2 hours (including Test Lab detour before pivoting to direct device debugging)
