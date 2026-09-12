# Flutter Mobile App Database Migration and APK Download Fix

**Date:** 2026-07-14
**Project:** HBEC
**Environment:** Production/Development
**Severity:** High
**Status:** Resolved

## Summary
The Flutter mobile application experienced recurring crashes on Android 15 devices while remaining stable on older devices (e.g., Android 11). Additionally, users downloading the newly released v5 APK from the web application were receiving a 3KB HTML file (`apk.html`) instead of the actual Android application package.

## Symptoms
- Flutter mobile app crashes on startup on Android 15 (64-bit devices) due to missing native binaries for the local database.
- Web app download link for the mobile app downloaded the Single Page Application's `index.html` fallback instead of the binary APK file.

## Environment Details
- **Server/Host:** HBEC VPS (for APK distribution)
- **Services Affected:** `student-frontend`, `mobile_flutter`
- **Related Components:** Local Database (Isar), Nginx Router (docker-compose)
- **Time First Observed:** 2026-07-14

## Investigation Steps

### 1. Initial Diagnosis
- Investigated the crash logs and found that the `isar_db_flutter_libs` fork used for the local database lacked native binaries for certain architectures or was causing incompatibility on Android 15.
- Investigated the web app's APK download button and found it pointed to `/downloads/hbec-student-v5.apk`. Since Nginx could not find the file, its `try_files` rule fell back to `index.html`.

### 2. Root Cause Analysis
- **Mobile Crash:** The `isar` package dependency and its native binaries were inherently incompatible or missing support for modern Android 15 devices (or specifically failing on 32-bit devices previously). Migrating away from Isar was required to resolve the native binary compatibility issues.
- **APK Download:** The `student-frontend` docker-compose configuration lacked a volume mount mapping the host's `/opt/hbec/downloads` directory (where the APKs are stored) to the Nginx container's `/usr/share/nginx/html/downloads` directory.

### 3. Key Findings
- Isar local database was deeply integrated into `AuthLocalDataSourceImpl`, `CurriculumLocalDataSourceImpl`, `ExamLocalDataSourceImpl`, and `SyncBloc`.
- The `vps_docker_compose.yml` on the VPS was correctly serving the frontend, but the volume mount was completely missing, causing Nginx to serve the SPA fallback.

## Root Cause
- Mobile crashes were caused by native binary incompatibilities in the `isar` NoSQL database package on newer Android versions.
- The web app download failure was caused by a missing volume mount in `docker-compose.yml`, causing Nginx to fallback to the SPA `index.html` for unknown routes.

## Prevention / Rule
**Guardrail:** an automated post-deploy check that `curl -I`s every advertised static download link (e.g. `/downloads/*.apk`) and asserts both a non-HTML `Content-Type` and a byte size above a sane floor — catching a missing volume mount immediately instead of waiting for a user's failed download to report it.

This covers the APK-download root cause specifically; the Isar/Android-15 native-binary incompatibility is a separate class of problem (an SDK/dependency choice, not a config gap) that a single guardrail here can't also close — it needs real-device testing before release, not a deploy-time check.

## Solution

### Immediate Fix
1. **Database Migration:** 
   - Replaced `isar` with `sqflite`.
   - Created a SQLite-compatible data transfer schema using standard SQL tables (`database_helper.dart` and `models.dart`).
   - Refactored all repository methods and `SyncBloc` to utilize the new `sqflite` implementation.
   - Handled nullability correctly for generated sqlite models to match the strict types in entity repositories.
2. **APK Download Fix:**
   - Modified `/opt/hbec/docker-compose.yml` on the VPS to add `- /opt/hbec/downloads:/usr/share/nginx/html/downloads:ro` to the `student-frontend` service.
   - Restarted the `student-frontend` container with `docker compose up -d student-frontend`.

### Long-term Fix
- Ensure all future database interactions in the mobile app are channeled through generic repository interfaces, minimizing lock-in to specific local database implementations.
- Ensure deployment scripts explicitly verify volume mounts for static binary distributions.

## Prevention
- [x] Configuration changes needed (docker-compose volume mapping)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (Isar to sqflite migration)

---

**Resolved By:** Antigravity AI
**Time to Resolution:** ~1 Hour
