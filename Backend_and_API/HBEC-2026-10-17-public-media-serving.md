# Public Media Serving May Expose Admin Uploads

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** Source audit; proxy exposure and file classification not yet verified
**Severity:** Medium
**Status:** Resolved in source; download-path migration pending

## Summary
The Admin Backend unconditionally registers Django's static `serve` view for `MEDIA_ROOT`, which is documented in the same file as containing admin-uploaded papers and marking schemes. If the route is publicly reachable, known or discoverable media paths can be downloaded without authentication or object-level authorization.

## Symptoms
- The application maps `media/<path>` directly to `settings.MEDIA_ROOT`.
- The source does not distinguish public branding assets from private educational uploads at this route.

## Environment Details
- **Server/Host:** HBEC Admin Backend
- **Services Affected:** `ADMIN/adminBackend`
- **Related Components:** Django media routing, admin uploads, reverse proxy
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Inspected the production URL configuration and the comments describing the contents of `MEDIA_ROOT`.

### 2. Root Cause Analysis
`config/urls.py:65` routes every path below `media/` to Django's unauthenticated file server, while the same file identifies the volume as containing admin-uploaded papers and schemes.

### 3. Key Findings
- `ADMIN/adminBackend/config/urls.py:51-65`
- `ADMIN/adminBackend/config/settings/production.py:98`

## Root Cause
Private and public media are stored behind one unauthenticated path without an authorization decision at file-download time.

## Prevention / Rule
**Guardrail:** Private uploads must never be served by a catch-all static file route; downloads must pass through an authenticated, object-authorized view or private storage URL.

This prevents a route or proxy change from exposing confidential educational material.

## Solution

### Immediate Fix
The Admin Backend catch-all `media/` route was removed, so Django no longer serves `MEDIA_ROOT` anonymously. Existing authenticated content-file routes remain the intended path for protected curriculum files.

### Long-term Fix
Inspect the active proxy and test a dummy confidential upload from an unauthenticated client. Separate public branding assets from private uploads and serve private files through authenticated object-scoped downloads or short-lived signed URLs.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## References
- `ADMIN/adminBackend/config/urls.py:51-65`
- `ADMIN/adminBackend/config/settings/production.py:98`

---

**Resolved By:** Pending
**Time to Resolution:** Pending
