# Added Admin-Managed Paynow Sandbox/Live Config — Guardrails Sourced From Prior Payment-Gateway Incidents

**Date:** 2026-09-17
**Project:** chemglee-concept-site
**Environment:** Development (ready for production; requires one new env var — see below)
**Severity:** N/A (proactive feature build, not an incident)
**Status:** Resolved

## Summary
Paynow was already fully wired into checkout (see the earlier
`chemglee-concept-site-2026-09-11-*` entries), but its integration ID/key
lived only in environment variables, with no sandbox/live distinction and no
way for staff to change them without a redeploy. Before building the
requested admin UI to manage this, searched this repo's own dev-logs for
prior payment-gateway incidents (mostly HBEC's ZB/Paynow work) and folded
their lessons directly into the design rather than repeating them:

- **HBEC-2026-09-10-model-settings-plaintext-key-storage…** — an
  "encrypted_key" field that was never actually encrypted. → New
  `apps.common.crypto.EncryptedCharField` (Fernet, keyed by a new
  `FIELD_ENCRYPTION_KEY` setting), used for both new Paynow key fields from
  the start. Verified the raw DB column really is ciphertext (a test reads
  the column directly with `connection.cursor()`, bypassing the ORM's own
  decryption) and that the admin API never returns a saved key — only
  whether one is set, same convention as the existing `NotificationSettings`
  admin API.
- **HBEC-2026-07-16-zb-payment-webhook-lockout** — a webhook/return URL left
  pointing at `localhost` after a migration, silently stranding every
  payment at "pending" in production. → `payments.start_payment()` now
  refuses to start a **live**-mode payment if `PAYNOW_RESULT_URL`/
  `PAYNOW_RETURN_URL` resolve to `localhost`/`127.0.0.1`/`0.0.0.0`/a private
  range, raising a clear `PaynowError` instead of silently accepting it.
  Sandbox mode is deliberately exempt (local dev testing needs this).
- **HBEC-2026-07-15-duckdb-payments-400** — a payment gateway "forgotten,
  not re-applied" after an environment migration, surfacing only as a
  generic 400 at checkout. → The admin API refuses to save `mode=live`
  unless both a live Integration ID and Key are present in that same
  request, with a specific error message, rather than allowing an
  inconsistent "live but unconfigured" state to be saved at all.
- **HBEC-2026-08-18-zb-payment-webhook-missing-check-status** — crediting a
  payment straight off a webhook payload's claimed status. → Not a new
  finding here: chemglee-concept-site's existing `PaynowResultView` already
  re-polls Paynow directly rather than trusting the webhook body (built in
  the original `933fc67` Paynow commit) — confirmed still correct, no change
  needed.

## What Was Built
- `apps/orders/models.py::PaynowConfig` — singleton (mode: sandbox/live,
  separate encrypted ID+key pairs per mode, `updated_by`/`updated_at`
  audit fields). A blank config falls back to the legacy
  `PAYNOW_INTEGRATION_ID`/`PAYNOW_INTEGRATION_KEY` env vars (treated as
  "live"), so an existing env-var-only deployment keeps working unchanged
  with no migration-day cutover.
- `apps/orders/migrations/0008_seed_paynowconfig_from_env.py` — a data
  migration that seeds the new config's live credentials from those same
  env vars on first deploy, purely so the admin page's "configured" status
  matches reality immediately rather than showing "not configured" on a
  deployment that's actually already working.
- `apps/orders/paynow.py`/`payments.py` updated to read credentials/mode
  from `PaynowConfig` on every call (never cached), with the URL guardrail
  above.
- `apps/orders/admin_api.py::AdminPaynowSettingsView` + `admin/src/routes/payments.tsx`
  — Shop Manager → Payments: mode toggle, sandbox/live credential fields
  (write-only, "saved — leave blank to keep it" convention), configured/
  not-configured badges per mode, an explicit "active mode" banner.
- 16 new tests (`apps/orders/tests/test_payments.py`) covering encryption
  round-trip, mode/fallback precedence, the live-mode URL guardrail (both
  directions), and the admin API's RBAC + secret-masking behavior. Full
  suite (273 tests) still green.

## One Deploy-Time Requirement
Production settings (`config/settings/production.py`) now hard-require a
new `FIELD_ENCRYPTION_KEY` env var (fails fast with `ImproperlyConfigured`
at startup if missing) — it's the Fernet key protecting the new encrypted
columns. **Not yet added to the production `.env`** — this session could
read but not write the VPS's env file (sandboxed). Must be generated and
added before the next deploy, or the backend container will fail to start:
```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```
Documented in `backend/.env.example` with a loud warning not to rotate it
casually (doing so makes every previously-saved credential unreadable).

## Related Issues
- `chemglee-concept-site-2026-09-17-notification-settings-plaintext-credential-storage.md` —
  found while doing this work: the existing `NotificationSettings` model
  (SMTP password, WhatsApp token) predates `EncryptedCharField` and still
  stores both in plaintext. Flagged, not fixed here (different scope/blast
  radius — needs a data migration against a populated production table).
- `chemglee-concept-site-2026-09-11-www-subdomain-cors-misconfiguration-served-stale-catalog.md`
  and its siblings — the original Paynow integration this builds on.

## References
- `backend/apps/common/crypto.py` (new — `EncryptedCharField`)
- `backend/apps/orders/models.py` (`PaynowConfig`)
- `backend/apps/orders/paynow.py`, `payments.py`
- `backend/apps/orders/admin_api.py` (`AdminPaynowSettingsView`)
- `backend/apps/orders/migrations/0007_paynowconfig.py`,
  `0008_seed_paynowconfig_from_env.py`
- `backend/config/settings/base.py`, `development.py`, `production.py`
  (`FIELD_ENCRYPTION_KEY`)
- `backend/.env.example`
- `admin/src/routes/payments.tsx`, `admin/src/lib/adminApi.ts`,
  `admin/src/components/AdminShell.tsx`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session
