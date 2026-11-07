# APK latest route served the SPA HTML instead of an APK

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
The first staging fix redirected the Android download button to the mobile
deployment script's `hbca.tech/downloads/hbec-student-latest.apk` path. The
route returned the landing page HTML with `200 text/html`, so it was not a
valid APK download.

## Symptoms
- The latest APK URL returned `200 text/html`.
- The response body began with `<!doctype html>`.
- The frontend's tracked versioned APK returned
  `200 application/octet-stream` with the expected APK-sized payload.

## Environment Details
- **Server/Host:** `hbca.tech`, staging student frontend
- **Services Affected:** Student Frontend, mobile download routing
- **Related Components:** `LoginPage.tsx`, `nginx.conf.template`,
  `.shipwright.yml`
- **Time First Observed:** 2026-11-07

## Investigation Steps

### 1. Initial Diagnosis
Checked the deployed login bundle, the redirected URL headers, and the first
bytes of the response.

### 2. Root Cause Analysis
The mobile deployment script's remote artifact directory was not the same
static directory served by the `hbca.tech` route in this environment. The
latest path therefore fell through to the landing-page SPA.

### 3. Key Findings
- `hbec-student-latest.apk` returned HTML.
- `hbec-student-v4.apk` was served by the student frontend as
  `application/octet-stream`.
- The old stable student-domain route needed to redirect locally, not to the
  landing-domain path.
- The compatibility redirect also needed an explicit HTTPS target because the
  reverse proxy presents HTTP to the frontend container.

## Root Cause
The frontend UI and mobile deployment directory were treated as one download
origin even though they are served by different paths and hosts.

## Prevention / Rule
**Guardrail:** Download-link smoke checks must assert both HTTP success and an
APK content type or ZIP/APK magic bytes; a `200` response alone is invalid.

This catches SPA fallbacks and proxy misroutes that otherwise look healthy to
link-only checks.

## Solution

### Immediate Fix
The login page now uses the frontend-relative tracked APK path,
`/downloads/hbec-student-v4.apk`, and the old stable URL redirects to that
same local artifact over HTTPS.

### Long-term Fix
Keep download URL validation tied to the actual static serving directory and
update the versioned artifact deliberately when a new APK is published.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `Frontend_and_UI/HBEC-2026-11-07-apk-download-link-404.md`

## References
- `STUDENT/Frontend/src/features/auth/pages/LoginPage.tsx`
- `STUDENT/Frontend/nginx.conf.template`
- `STUDENT/Frontend/public/downloads/hbec-student-v4.apk`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
