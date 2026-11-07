# Student APK download link returned the SPA 404 page

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** Production-facing student frontend
**Severity:** Medium
**Status:** Resolved

## Summary
The student login page linked to `/downloads/hbec-student.apk`, but that
filename was not present in the frontend's public assets and was not produced
by the Flutter deployment script. Requests therefore fell through to the SPA
fallback and showed the 404 page instead of downloading the Android app.

## Symptoms
- Selecting **Android app** from the login page opened the frontend 404 page.
- The requested stable filename was absent from `STUDENT/Frontend/public/downloads/`.
- The mobile deployment script publishes `hbec-student-latest.apk` and a
  versioned APK on `hbca.tech`, not `hbec-student.apk` on `student.hbca.tech`.

## Environment Details
- **Server/Host:** `student.hbca.tech` / `hbca.tech`
- **Services Affected:** Student Frontend, Flutter mobile artifact publishing
- **Related Components:** `LoginPage.tsx`, `nginx.conf.template`,
  `scripts/deploy-flutter-mobile.sh`
- **Time First Observed:** 2026-11-07

## Investigation Steps

### 1. Initial Diagnosis
Inspected the login-page fallback URL, the frontend public download directory,
the frontend Nginx configuration, and the Flutter deployment script.

### 2. Root Cause Analysis
The login page referenced a filename that had no corresponding static file.
The deployment script's maintained stable artifact is
`https://hbca.tech/downloads/hbec-student-latest.apk`.

### 3. Key Findings
- `hbec-student.apk` was absent from the tracked frontend assets.
- `hbec-student-v4.apk` existed only as a versioned static artifact.
- The deployment script publishes `hbec-student-latest.apk` to the landing
  page download directory.

## Root Cause
The frontend download link and the mobile artifact deployment contract drifted:
the UI retained an old stable filename while the build script switched to a
versioned/latest artifact path.

## Prevention / Rule
**Guardrail:** Keep one canonical APK download URL in the frontend and mobile
deployment script, and add a focused test that asserts the login link targets
that URL.

The shared contract prevents a renamed mobile artifact from silently becoming
an SPA route and makes future filename drift fail in the frontend test suite.

## Solution

### Immediate Fix
The login page now points at the maintained
`https://hbca.tech/downloads/hbec-student-latest.apk` artifact. The frontend
also redirects the old `/downloads/hbec-student.apk` URL to that artifact so
existing bookmarks no longer fall through to the SPA 404 page.

### Long-term Fix
Keep the latest artifact name stable in the mobile deployment script and cover
the frontend link plus compatibility route in regression checks.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None

## References
- `STUDENT/Frontend/src/features/auth/pages/LoginPage.tsx`
- `STUDENT/Frontend/nginx.conf.template`
- `scripts/deploy-flutter-mobile.sh`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
