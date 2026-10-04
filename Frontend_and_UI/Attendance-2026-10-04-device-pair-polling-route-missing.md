# Device pair-status polling 404s (missing route) and QR uses dead CDN

**Date:** 2026-10-04
**Project:** Attendance
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The device-pairing confirmation page polls `/devices/pair-status/{code}` every 2s, but no Laravel route defines that URL, so polling always 404s. The QR code itself is rendered via `cdn.rawgit.com`, a discontinued CDN, and a stray `patch_controller.php` hack that duplicated the missing method is still committed at the admin root.

## Symptoms
- Pairing page QR may fail to render once rawgit is unreachable.
- Browser console shows repeated 404s to `/devices/pair-status/{code}`; page never auto-redirects on successful pair.
- `admin/patch_controller.php` contains a regex-based file-patch script targeting `DeviceController.php`, already merged yet still present.

## Environment Details
- **Server/Host:** Laravel admin (`admin/`)
- **Services Affected:** `GET /devices/*` pairing flow
- **Related Components:** `admin/resources/views/devices/pair.blade.php:22,36`, `admin/app/Http/Controllers/DeviceController.php:66-75`, `admin/routes/web.php`, `admin/patch_controller.php`
- **Time First Observed:** 2026-10-04, during admin-dashboard audit

## Investigation Steps

### 1. Initial Diagnosis
Read the pair view polling JS, then `routes/web.php` — the polled path has no route entry.

### 2. Root Cause Analysis
`DeviceController::checkPairStatus` exists but is unreachable (no route). A root-level `patch_controller.php` script re-appends the same method via regex, indicating a manual patch was run instead of editing the controller + routes properly, then left behind.

### 3. Key Findings
- Orphan controller method + missing route = dead live-status path.
- External QR dependency on a dead CDN (`cdn.rawgit.com/davidshimjs/qrcodejs`).
- Patch-script file in repo root is a process smell: unreviewed code modification outside version control discipline.

## Root Cause
The pair-status endpoint was added to the controller via an ad-hoc patch script without adding the corresponding route or vendoring the QR dependency, and the scaffolding script was committed rather than deleted.

## Prevention / Rule
**Guardrail:** CI check that every `fetch(...)` path in Blade views resolves to a defined Laravel route (or documented external host), plus a ban on root-level `patch_*.php` scripts via code-review checklist.

This closes the gap directly: the root cause is an unreachable internal endpoint plus an external dead dependency; a route-reachability check catches both classes.

## Solution

### Immediate Fix
Applied 2026-10-04 (Phase 0): added `Route::get('/devices/pair-status/{code}')` → `checkPairStatus`; deleted `admin/patch_controller.php`; QR script moved from dead `cdn.rawgit.com` to verified-alive `cdn.jsdelivr.net/gh/davidshimjs/qrcodejs/qrcode.min.js`. `php -l` clean on routes + controller.

### Long-term Fix
Contract/smoke test: generate pairing token on staging, poll status, complete pair from a test client, assert redirect.

## Prevention
- [ ] Configuration changes needed: none
- [ ] Monitoring/alerts to add: none
- [ ] Documentation to update: `docs/admin-dashboard-plan.md` Phase 0 (done)
- [ ] Code changes required: add route; delete patch script; vendor QR lib

## Related Issues
- None known.

## References
- `admin/resources/views/devices/pair.blade.php`
- `admin/app/Http/Controllers/DeviceController.php`
- `admin/routes/web.php`
- `admin/patch_controller.php`
- `docs/admin-dashboard-plan.md`

---

**Resolved By:** Phase 0 fix session
**Time to Resolution:** Same day (audit → fix)
