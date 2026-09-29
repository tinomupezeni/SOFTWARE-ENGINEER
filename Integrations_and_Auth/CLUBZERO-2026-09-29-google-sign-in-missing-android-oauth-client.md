# Google Sign-In failed with `PlatformException(sign_in_failed)` — Firebase never had an Android OAuth client registered

**Date:** 2026-09-29
**Project:** Club Zero
**Environment:** Development
**Severity:** High (the entire feature — the user's explicit reason for wanting Google Sign-In, "most users would want to quickly sign up" — was completely non-functional)
**Status:** Resolved

## Summary
After wiring up Google Sign-In (Flutter `google_sign_in` + `firebase_auth`
→ backend `POST /auth/google` verifying the Firebase ID token via
`firebase-admin`), tapping "Continue with Google" on a real device always
failed with a `PlatformException` (`sign_in_failed`) immediately after
picking an account in the native picker. The backend never even received a
request — this was purely a client-side failure in the Google Sign-In SDK
itself, before any of this session's own code ran.

## Symptoms
- Tapping "CONTINUE WITH GOOGLE" opened the native account picker
  correctly, the user could select an account, but the sign-in then failed
  with a `PlatformException` reporting `sign_in_failed`.
- No `POST /auth/google` request ever reached the backend (confirmed via
  `docker logs` — the endpoint was never hit), ruling out a backend bug.
- The app's own try/catch handled the exception cleanly (a `SnackBar`
  appeared, no crash) — this made it look like a "your code has a bug"
  failure at first glance, when it was actually the Google Play Services
  SDK refusing to complete the flow at all.

## Environment Details
- **Server/Host:** N/A — entirely a client + Google/Firebase console
  configuration issue, no backend code involved.
- **Services Affected:** `club_zero_mobile` Flutter client
  (`lib/services/google_auth_service.dart`), Firebase project
  `club-zero-b7ebc`'s Google Sign-In OAuth configuration.
- **Time First Observed:** 2026-09-29, on the first real end-to-end test of
  the newly-built Google Sign-In feature on a physical Android device.

## Investigation Steps

### 1. Initial Diagnosis
`adb logcat` around the failure showed the native
`SignInHubActivity`/`SignInActivity` (Google Play Services) launching and
tearing down normally — the picker genuinely opened and a selection was
made — but no Dart-level diagnostic output appeared at all, and no request
ever reached the backend. This pointed at a failure inside the native
Google Sign-In SDK itself, between "account picked" and "credential
returned to the app."

### 2. Root Cause Analysis
Initial diagnostic logging was added using `dart:developer`'s `log()`,
which produced *no output whatsoever* in the release build — this is a
known gap: `dart:developer` log calls are only observable when a VM
service/DevTools connection is attached, which a standard
`flutter build apk --release` does not have. Switched to `debugPrint()`
(which Flutter always forwards to `adb logcat` under the `flutter` tag,
release or debug, regardless of VM service state) and rebuilt.

With real diagnostics in place, the actual failure was traced by
inspecting `android/app/google-services.json`:
```
"oauth_client": [
  {
    "client_id": "726060838011-id56qdqqkdsbnd69nn5glngpp9pl1beu.apps.googleusercontent.com",
    "client_type": 3
  }
]
```
Only a **web** OAuth client (`client_type: 3`) existed — there was no
**Android** OAuth client (`client_type: 1`, which carries a
`certificate_hash` tying it to the app's package name + signing
certificate). Without that Android client, Google's servers have no record
that this specific signed APK is allowed to authenticate against this
Firebase project at all, which is exactly what `PlatformException
sign_in_failed` (Google Play Services error code 10, `DEVELOPER_ERROR`)
means.

### 3. Key Findings
- Registering the debug keystore's SHA-1 fingerprint under Firebase
  **Project settings → (Android app) → SHA certificate fingerprints** is a
  *separate, required* step from enabling the Google provider under
  **Authentication → Sign-in method** — both must be done, and the
  Android OAuth client is only generated (and only appears in a freshly
  re-downloaded `google-services.json`) after the fingerprint is
  registered and saved.
- The first attempt at this (earlier the same day, during the initial
  Google Sign-In build) added the fingerprint and re-downloaded the file,
  but the file still only had the web client — the fingerprint save likely
  didn't fully take effect, or the re-download happened before Google's
  side finished generating the Android client. A second, explicit
  re-verification (checking the fingerprint was actually listed in the
  console before re-downloading) resolved it.
- `dart:developer`'s `log()` being silent in release builds is a real,
  separate gotcha worth remembering for any future release-mode debugging
  on this project — `debugPrint()` is the reliable choice.

## Root Cause
Firebase's Android OAuth client for this app was never actually generated
— the SHA-1 fingerprint registration didn't take effect the first time it
was attempted, so every `google-services.json` download kept coming back
with only the web client, and Google Play Services correctly refused to
authenticate a signing certificate it had no record of.

## Prevention / Rule
**Guardrail:** After registering a SHA fingerprint for Google Sign-In,
verify it visually in the Firebase console list (not just that the "Add"
action didn't error) before re-downloading `google-services.json`, and
after downloading, grep the file for `"client_type": 1` before assuming
the config is complete — an absent Android `oauth_client` entry is the
single most reliable signal that this exact failure is coming.

Also: **use `debugPrint()`, never `dart:developer`'s `log()`, for any
diagnostic output meant to survive into a release-mode build** — the
latter is silently a no-op without an attached VM service.

## Solution

### Immediate Fix
No application code changed to fix the root cause — this was purely a
Firebase console configuration gap. The user re-verified the SHA-1
fingerprint was actually saved in the console, then re-downloaded
`google-services.json`; the file then correctly included an Android
`oauth_client` (`client_type: 1`) with `certificate_hash:
3f301c53c5d673e85a782f80a2a7417e5ce890af`, matching the debug keystore.
Rebuilt and reinstalled the release APK with the corrected file.

Diagnostic logging in `lib/services/google_auth_service.dart` was switched
from `dart:developer`'s `log()` to `debugPrint()` as part of this
investigation — kept in place going forward since it made this exact class
of failure fast to diagnose from `adb logcat` alone.

### Long-term Fix
None needed — this is a one-time console configuration step per signing
certificate. Worth remembering when a release signing key is eventually
added (see `android/app/build.gradle`'s TODO about using the debug key for
release builds for now): that new key's SHA-1 will need registering the
same way before Google Sign-In works on a build signed with it.

## Verification
End-to-end confirmed via `adb logcat` (client) and `docker logs` (server)
together: `[GoogleAuthService] Picked account: <email>` →
`idToken present: true, accessToken present: true` → `Firebase sign-in OK,
got ID token: true` on the client, immediately followed by
`POST /auth/google HTTP/1.1" 200 OK` on the backend, then normal
authenticated traffic (`GET /clubs/me`, WebSocket connect, habit
completions) — the full flow works.

## Prevention
- [x] Fix applied (Firebase console fingerprint re-verified, config
      re-downloaded, app rebuilt)
- [ ] Configuration changes needed — none further
- [ ] Monitoring/alerts to add — none, one-time console setup issue
- [x] Documentation to update — `DEVLOG.md`
- [x] Code changes required (debugPrint diagnostics, kept permanently)

## Related Issues
- None filed yet.

## References
- `club_zero_mobile/lib/services/google_auth_service.dart`
- `club_zero_mobile/android/app/google-services.json`
- Report: `SOFTWARE-ENGINEER/reports/CLUBZERO-2026-09-29-google-signin-onboarding-guide-profile-screen.md`

---

**Resolved By:** Claude (Sonnet 5), with the user re-verifying the Firebase console state, for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session, 2026-09-29.
