# Feedback-reply emails rendered with a broken (404) logo image

**Date:** 2026-10-06
**Project:** HBEC
**Environment:** Production (Admin Backend, student-facing emails)
**Severity:** Low (cosmetic — the email itself still sends and is readable)
**Status:** Resolved

## Summary
Student-facing emails (feedback replies, password reset/changed notices) are
templated with branding fetched from Admin Backend's `emailBranding`
settings. The `logoUrl` field defaulted to
`https://admin.hbca.tech/media/branding/logo.svg` — a URL that had never
actually had a file placed behind it. No admin had customized this setting
either (the live API was still returning the hardcoded default for every
field), so every environment that ever sent a branded email was serving a
404 in place of the logo, invisibly, until a user reported it.

## Symptoms
- User report: "the email being sent, its going but its missing the logo,
  rather the logo is kinda 404 on the sent email."
- `curl https://admin.hbca.tech/media/branding/logo.svg` → `404`.
- `GET /api/settings/email-branding/` on production returned the exact
  hardcoded `DEFAULTS["emailBranding"]` dict, confirming nobody had ever
  saved a real value for any field in this category, not just `logoUrl`.

## Environment Details
- **Server/Host:** `hbca-vps`, Admin Backend
- **Services Affected:** `hbec-admin-backend-{blue,green,unsuffixed}` (all
  three share one `hbec_admin_media` Docker volume — confirmed directly;
  not a per-color isolation issue), Student Backend's outgoing email
  templating (`core/branded_email.py`)
- **Related Components:** `apps/system_settings/views.py`
  (`SettingsCategoryView.DEFAULTS["emailBranding"]`), the `/media/` proxy
  chain (Caddy → `admin-frontend`'s nginx `location /media/` → Admin
  Backend's `MEDIA_ROOT`)
- **Time First Observed:** 2026-10-06, user report

## Investigation Steps

### 1. Initial Diagnosis
`curl`'d the configured logo URL directly — genuinely 404, not an
email-client rendering/caching quirk.

### 2. Root Cause Analysis
```bash
# Confirmed the file doesn't exist anywhere in the shared volume, on any color:
docker exec hbec-admin-backend-green find / -iname 'logo.svg' 2>/dev/null   # nothing
docker exec hbec-admin-backend-green ls /app/media/branding/                 # No such file or directory

# Confirmed all three colors share one volume (rules out per-color isolation):
docker inspect hbec-admin-backend-{green,blue,admin-backend} --format '{{range .Mounts}}...{{end}}' | grep media
# -> all three: hbec_admin_media -> /app/media
```
Code search (`ADMIN/adminBackend/apps/system_settings/`) found no
FileField/ImageField/upload endpoint anywhere in this app — `logoUrl` is a
plain string in a generic key/value `SystemSetting` JSON blob, handled
identically to `brandName`/`footerText`. The frontend's "Logo URL" input
(`SystemSettingsPage.tsx`) is a plain text field, not a file picker — by
design, an admin is expected to paste a URL to an already-hosted image.
The default value itself assumed a file would exist at Admin Backend's own
`/media/` mount, but nothing — no migration, no deploy step, no manual
upload — had ever put one there.

### 3. Key Findings
- This is not specific to one admin's misconfiguration: the live API was
  still returning pure `DEFAULTS`, meaning this would 404 identically on
  *any* HBEC environment that had never had someone manually place a file
  at that exact path.
- The app's own favicon (`ADMIN/adminFrontend/public/favicon.svg`, byte-
  identical to Student Frontend's) is a real, intentional HBCA brand mark
  (green/gold heritage shield) — matching the user's own in-progress brand
  color edit (`#407934`) far better than the PWA icon set's unrelated blue
  "H" mark, which was the only other candidate asset in the repo.

## Root Cause
A convincing-looking default setting (`logoUrl` pointing at this domain's
own `/media/` mount) with no corresponding provisioning step anywhere in
code, infrastructure, or documentation — the default assumed a manual step
that was never performed on any environment.

## Prevention / Rule
**Guardrail:** `TestProvisionDefaultEmailLogo` (new) pins both the
provisioning behavior and its idempotency (never overwrites a file an
admin has since uploaded over it) — a future change to this migration or
the default path that breaks either property fails the test immediately,
rather than surfacing as another silent 404 months later.

## Solution

### Immediate Fix
- Rendered the real brand mark (the shared favicon SVG) to a 256×256 PNG
  via headless Chrome (SVG was the original format, but email clients —
  Outlook especially — have unreliable inline-SVG support, so PNG is the
  safer universal choice).
- Placed it at `/app/media/branding/logo.png` in the shared
  `hbec_admin_media` volume directly (one-off `docker cp`, applies to all
  three colors immediately since they share the volume) and updated the
  live `logoUrl` setting via the real admin API to point at it — confirmed
  `200`, correct `image/png` content-type, and the setting change persisted.

### Long-term Fix
**Applied same session**, not deferred: committed the PNG into the repo
(`apps/system_settings/default_assets/default_email_logo.png`) and added
migration `0008_provision_default_email_logo`, which copies it into
`MEDIA_ROOT/branding/logo.png` on every environment's next `migrate`
(Django migrations run automatically at container startup per this
project's entrypoints) — idempotent, never overwrites an admin's own
upload. Also changed `DEFAULTS["emailBranding"]["logoUrl"]`'s extension
from `.svg` to `.png` to match. This closes the pattern, not just today's
instance: any future fresh environment (a new deploy color, a disaster
recovery restore, a local dev setup) gets a real logo automatically
instead of inheriting this exact 404.

## Prevention
- [x] Code change applied and tested (119 tests passed across
      `system_settings`/`replication`, no regressions)
- [x] Migration provisions the default on every environment going forward
- [ ] Consider whether `emailBranding` should eventually gain a real file
      upload path (the admin UI's text-field approach is still awkward for
      the few teams that want their own custom logo) — product decision,
      out of scope here

## Related Issues
- None — first incident logged against this feature.

## References
- `ADMIN/adminBackend/apps/system_settings/views.py`
  (`SettingsCategoryView.DEFAULTS["emailBranding"]`)
- `ADMIN/adminBackend/apps/system_settings/migrations/0008_provision_default_email_logo.py`
- `ADMIN/adminBackend/apps/system_settings/default_assets/default_email_logo.png`
- `STUDENT/hbec_backend/core/branded_email.py` (the consumer, fetches fresh
  on every send — no cache invalidation needed for this fix to take effect)
- `ADMIN/adminFrontend/nginx.conf.template` (`location /media/` proxy chain)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Same session as discovery
