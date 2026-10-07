# Issue: Google Sign-In PlatformException (Developer Error 10) during Remote ADB

## Description
When attempting to use Google Sign-In ("Continue with Google") on the registration screen, the Flutter app threw a `PlatformException: 10` (DEVELOPER_ERROR). This error occurred because the app was deployed via a remote `flutter run` session, which signs the APK with the remote environment's `debug.keystore`. The SHA-1 fingerprint of this remote keystore is not registered in the project's Firebase/Google Cloud Console, causing Google's OAuth validation to fail.

## Resolution
This is expected behavior for remote compilation. The immediate workaround is to use the Email/Password sign-up flow which bypasses Google SDK signature checks. Google Sign-In will automatically resume functioning once the APK is built using the local development machine's keystore or the production release keys.

## Resolved By
Antigravity
