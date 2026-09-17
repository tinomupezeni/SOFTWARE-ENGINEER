# NotificationSettings Stores the SMTP Password and WhatsApp Access Token in Plaintext

**Date:** 2026-09-17
**Project:** chemglee-concept-site
**Environment:** Production + Development
**Severity:** Medium (real credentials at rest, unencrypted — no known exploitation, found proactively)
**Status:** Found, not yet fixed (out of scope for the session that found it)

## Summary
Found while building admin-managed Paynow sandbox/live credentials (which
needed real encryption at rest) and cross-checking this repo's dev-logs for
prior payment/secret-storage incidents. `apps/notifications/models.py`'s
`NotificationSettings` singleton — the admin-editable SMTP/WhatsApp alert
config — stores `email_host_password` and `whatsapp_access_token` as plain
`CharField`s. Both are real third-party credentials (an SMTP app password, a
Meta WhatsApp Cloud API permanent access token) sitting in the database
unencrypted. `apps/notifications/admin.py`'s `NotificationSettingsForm` even
uses `forms.PasswordInput(render_value=True)`, which re-populates the actual
plaintext value into the Django-admin form on every page load.

## Symptoms
None observed — not a live incident. Found by inspection while designing
`apps.common.crypto.EncryptedCharField` for the new `PaynowConfig` model, then
noticing `NotificationSettings` (the existing precedent for "admin-editable
secret") predates that field and never got real encryption.

## Environment Details
- **Services Affected:** Django backend (`apps/notifications`), both the
  React admin API (`admin_api.py` — never returns the raw value, only a
  `..._set` boolean, which is good) and the break-glass Django admin
  (`admin.py` — does render the raw value back into the form)
- **Time First Observed:** 2026-09-17, while implementing
  `chemglee-concept-site-2026-09-17-paynow-sandbox-live-admin-config.md`
  (this session's Paynow admin work, in `DevOps_and_Infrastructure/`)

## Root Cause
`NotificationSettings` was built before any field-level encryption utility
existed in this codebase. The React admin API layer already followed the
right shape (never round-trip the secret, only a boolean), but the
underlying storage was never actually encrypted — the field is just a
`CharField`, and the Django-admin form's `render_value=True` compounds it by
also exposing the plaintext in that surface's page source on every load.

## Prevention / Rule
**Guardrail:** Any Django field holding a real third-party credential must be
`apps.common.crypto.EncryptedCharField`, never a plain `CharField` — this is
exactly the pattern that field type exists to enforce (see the HBEC dev-log
this was modeled on: a field literally named `encrypted_key` that stored
plaintext for months because nothing forced the name to be true). A quick
repo-wide grep for field names containing `password`, `token`, `secret`, or
`key` that aren't `EncryptedCharField` would have caught this immediately;
worth running once as a one-off audit rather than relying on catching each
case by inspection.

## Solution

### Immediate Fix
None applied in this session — flagged for a separate, deliberate pass since
it touches an existing production table and needs a real data migration
(encrypt the two existing plaintext values in place, not just change the
field type going forward), which is a different shape of change than the new
`PaynowConfig` model this session was actually asked to build.

### Long-term Fix
1. Change `email_host_password`/`whatsapp_access_token` to
   `apps.common.crypto.EncryptedCharField`.
2. A data migration that reads each existing plaintext value with the old
   field type and re-writes it through the new one (so it's encrypted in
   place, not silently dropped).
3. Drop `render_value=True` from `NotificationSettingsForm`'s
   `PasswordInput` widgets, and accept the same "blank stays unchanged"
   convention the React admin API already uses, so the Django-admin surface
   stops rendering the live secret into page HTML at all.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [ ] Code changes required — field type change + data migration +
      `render_value=True` removal, as above

## Related Issues
- `chemglee-concept-site-2026-09-17-paynow-sandbox-live-admin-config.md`
  (`DevOps_and_Infrastructure/`) — the new Paynow admin config this session
  built used `apps.common.crypto.EncryptedCharField` from the start
  specifically to avoid repeating this.

## References
- `backend/apps/notifications/models.py` (`NotificationSettings`)
- `backend/apps/notifications/admin.py` (`NotificationSettingsForm`)
- `backend/apps/notifications/admin_api.py` (`AdminNotificationSettingsView`
  — already correct about never returning the raw value; the gap is storage,
  not the API shape)
- `backend/apps/common/crypto.py` (the encryption utility now available to
  fix this with)

---

**Resolved By:** Not yet — found and logged by Claude Sonnet 5, fix deferred
**Time to Resolution:** N/A
