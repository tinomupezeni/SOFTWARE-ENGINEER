# Flutter APK download served stale artifact

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** Production/Staging deployment pipeline
**Severity:** High
**Status:** Workaround Applied

## Summary
The student download page served an old Flutter APK because the mobile deployment
script published to the landing-page downloads directory, while the production
student frontend serves `/opt/hbec/downloads`. The same script built without the
production `API_BASE_URL`, leaving release builds on the Android emulator
fallback.

## Symptoms
- Students downloaded an older mobile build.
- The downloaded app was not guaranteed to reach the production backend.
- The published `latest` artifact was absent from the directory mounted by the
  student frontend.

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** Student frontend download route; Flutter release pipeline
- **Related Components:** `scripts/deploy-flutter-mobile.sh`, Flutter DI, production compose volume
- **Time First Observed:** 2026-11-07

## Investigation Steps

### 1. Initial Diagnosis
Inspected the Flutter build configuration, mobile deployment script, production
compose mounts, and APK files present on the VPS.

### 2. Root Cause Analysis
```bash
ssh hbca-vps 'ls -lh /opt/hbec/downloads'
ssh hbca-vps 'ls -lh /home/winstontino/projects/landing-page/downloads'
```

### 3. Key Findings
- Production compose mounts `/opt/hbec/downloads` into the student frontend.
- The deploy script copied APKs to `/home/winstontino/projects/landing-page/downloads`.
- The deploy script invoked `flutter build apk --release` without a production
  Dart define.

## Root Cause
The mobile publishing path and the frontend serving path had drifted, and the
release command bypassed the explicit API configuration contract already enforced
by `STUDENT/mobile_flutter/scripts/build_release.sh`.

## Prevention / Rule
**Guardrail:** The Flutter deployment script must publish to the directory
declared by the production compose frontend volume and must pass explicit
production `API_BASE_URL` and `WEB_BASE_URL` Dart defines.

This keeps the artifact identity and serving path coupled in one release command
and prevents emulator-only builds from being published as production releases.

## Solution

### Immediate Fix
Updated the deployment script to publish to `/opt/hbec/downloads`, build against
`https://student.hbca.tech/api`, and publish the stable `latest` URL. Bumped the
Flutter app to version `1.0.4+8`.

### Long-term Fix
Keep the compose mount, deployment script, and frontend download URL aligned;
add a release smoke check that compares the served APK metadata with the build
version and rejects localhost/emulator API values.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `HBEC-2026-11-07-apk-download-link-404.md`
- `HBEC-2026-11-07-apk-latest-route-served-html.md`

## References
- `docker-compose.production.yml`
- `scripts/deploy-flutter-mobile.sh`
- `STUDENT/mobile_flutter/lib/core/di/injection.dart`

---

**Resolved By:** Copilot
**Time to Resolution:** In progress
