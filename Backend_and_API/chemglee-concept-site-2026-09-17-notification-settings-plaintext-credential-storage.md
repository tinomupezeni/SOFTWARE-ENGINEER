# NotificationSettings Stores the SMTP Password and WhatsApp Access Token in Plaintext

**Date:** 2026-09-17
**Project:** chemglee-concept-site
**Environment:** Production + Development
**Severity:** Medium (real credentials at rest, unencrypted — no known exploitation, found proactively)
**Status:** Resolved (2026-09-18)

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
Done, 2026-09-18 (deferred from the original 2026-09-17 finding, then fixed
the same week rather than left queued):

1. `email_host_password`/`whatsapp_access_token` changed to
   `apps.common.crypto.EncryptedCharField` (`backend/apps/notifications/models.py`).
2. `backend/apps/notifications/migrations/0002_encrypt_stored_secrets.py` —
   a data migration that captures each row's plaintext value *before* the
   field-type change (via the historical pre-migration model), then
   re-writes it *after* via `.update()` — encrypting it in place rather
   than losing it. Caught a real bug in the first draft of this migration
   while testing it: writing the captured value back via `.get()` +
   `.save()` fails, because fetching the row through the now-changed field
   tries to decrypt the still-plaintext bytes sitting in the column and
   raises before the overwrite ever happens. `.update()` issues a direct
   UPDATE without reading first, avoiding that. Verified against a
   simulated pre-existing production row (inserted via raw SQL under the
   old schema, migrated, then read back through the ORM): original
   plaintext values survive the migration exactly, and the raw column
   holds ciphertext throughout.
3. `NotificationSettingsForm` (`admin.py`) no longer uses
   `render_value=True` — the two fields are now explicitly declared,
   always render blank, and a blank submission keeps the previously saved
   value (`clean_email_host_password`/`clean_whatsapp_access_token`) — the
   same "blank means unchanged" convention `AdminNotificationSettingsView`
   already used.
4. 4 new tests (`apps/notifications/tests/test_admin.py`): raw-column
   ciphertext check, "the change page never renders the saved secret in
   its HTML," blank-keeps-existing, and new-value-overwrites-old. Full
   suite (363 tests) green; `makemigrations --check` clean.

### Long-term Fix
None needed beyond the above — this is the complete fix.

## Prevention
- [x] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [x] Code changes required — done (see Solution)

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

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found 2026-09-17, fixed 2026-09-18 (one day, deferred
deliberately rather than rushed into the original session)
