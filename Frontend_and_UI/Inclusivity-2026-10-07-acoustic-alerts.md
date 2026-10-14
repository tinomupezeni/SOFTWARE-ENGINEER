---
type: dev-log
project: Inclusivity
component: AcousticAlertService
issue_type: feature
status: resolved
---

# Issue Description
The Home Mode required "Background Acoustic Listening" to warn Deaf/Hard-of-Hearing users of important environmental sounds (like door knocks, fire alarms, or baby cries), while operating 100% offline within strict Android Go memory constraints.

# Resolution
Implemented `AcousticAlertService` using TensorFlow Lite Task Audio library.
1. Downloaded the `yamnet.tflite` model (approx. 4MB) to the app's `assets` folder. This is lightweight enough to avoid OOM errors on low-end devices.
2. The service listens via microphone and classifies audio every 1 second against 521 YamNet classes.
3. The alerts are filtered by a strict subset (e.g., "Knock", "Alarm", "Fire alarm", "Siren", "Emergency vehicle", "Baby cry") to avoid spamming the user.
4. Hooked the `AcousticAlertService` into `MainActivity`'s lifecycle and wired it to the toggle switch on the `HomeModeScreen`. Alerts appear in red underneath the switch dynamically.

**Resolved By**: Antigravity
