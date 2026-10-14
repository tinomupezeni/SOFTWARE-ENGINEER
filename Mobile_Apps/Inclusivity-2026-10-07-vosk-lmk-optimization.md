# Vosk STT Model Android Low Memory Killer (LMK) Risk

**Date:** 2026-10-07
**Project:** Inclusivity
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The Vosk Speech-to-Text engine was loading its 50MB+ acoustic model into memory unconditionally on app start (`onCreate`) and keeping the C++ instances alive continuously. On low-end Android Go devices (1-2GB RAM), holding this much memory in the background would guarantee the OS aggressively terminating the application via the Low Memory Killer (LMK), making the offline-first experience brittle and unreliable.

## Symptoms
- App consumes a consistent 60-80MB of baseline RAM while completely idle in the background.
- High risk of Android Low Memory Killer (LMK) evicting the app while the user is navigating away briefly.

## Environment Details
- **Services Affected:** `VoskSttService.kt`
- **Related Components:** `MainActivity.kt`
- **Time First Observed:** 2026-10-07

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the lifecycle integration of the Vosk engine. `voskSttService?.init()` was explicitly called in `MainActivity.onCreate()` and destroyed only in `onDestroy()`.

### 2. Root Cause Analysis
Because the heavy Kaldi C++ decoder objects (`Model`, `Recognizer`) are mapped into memory immediately and never released when the app moves to the background (`onStop`), the app creates severe memory pressure on budget ARM devices.

## Root Cause
Lack of lifecycle-aware resource management for heavy JNI STT models.

## Prevention / Rule
**Guardrail:** Heavy JNI/AI Model Lifecycle Management
Any heavy offline AI model (Vosk, TFLite, ONNX) loaded in the mobile application must implement `androidx.lifecycle.DefaultLifecycleObserver`. These models *must* be eagerly dropped from memory in `onStop()` and lazily re-allocated in `onStart()`.

This guarantees the app slims down to Android Go's safe background threshold when minimized, preventing LMK termination.

## Solution

### Immediate Fix
1. Refactored `VoskSttService` to implement `DefaultLifecycleObserver`.
2. Created a `releaseResources()` function to explicitly call `.close()` on both `Model` and `Recognizer` when `onStop` fires.
3. Moved initialization to `onStart` so the model is only loaded into RAM when the UI is actually visible to the user.
4. Registered the service with the Activity's lifecycle: `lifecycle.addObserver(voskSttService!!)`.

### Long-term Fix
Ensure any future background acoustic listening services (like wake-word detection) use heavily quantized models separately, leaving the main Vosk STT model tied to foreground lifecycle events.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- STT Offline capability requirements (ADR 2).

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
