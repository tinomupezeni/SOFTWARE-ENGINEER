# Payment Settings Encryption Key Drift Causes API Failures

**Date:** 2026-09-20
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The Staging payments service began failing with `400 Bad Request` during checkout. ZB Bank API requests were failing with `401 Unauthorized`. Investigation revealed that the ZB Sandbox API keys stored in the admin database were failing to decrypt, resulting in the raw ciphertext being sent to the payment gateway. This was caused by the Django `SECRET_KEY` evaluating to `"dummy"` due to a duplicate environment variable definition, while the original keys were encrypted with a different key.

## Symptoms
- Checkout failed with `400 Bad Request` on `/api/payments/initiate/`.
- `hbec-payments-staging` logged: `Real ZB payment initiation failed for ZB-M-...: ZB API returned status 401: Unauthorized. Api Secret Error`.
- The Admin Backend's internal API (`/_internal/settings/payment/`) returned the `zbApiKey` and `zbSecretKey` as `enc::...` ciphertext instead of decrypting them.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** `hbec-payments-staging`, `hbec-admin-backend-staging`
- **Related Components:** Django Admin System Settings, Payment Gateway Integration
- **Time First Observed:** 2026-09-20 16:20

## Investigation Steps

### 1. Initial Diagnosis
The 400 Bad Request on the frontend led to inspecting the `hbec-payments-staging` container logs, which revealed the `401 Unauthorized` response from ZB Bank. 

### 2. Root Cause Analysis
The payments service dynamically fetches API keys from the admin backend (`http://admin-backend:8000/_internal/settings/payment/`). Testing this endpoint directly showed that the keys were being returned as raw ciphertext (`enc::...`).
I reviewed the `decrypt_value` function in `apps/system_settings/views.py`. It falls back to `django_settings.SECRET_KEY` when `SETTINGS_ENCRYPTION_KEY` is not set.

### 3. Key Findings
- `.env.staging` had a duplicate definition for `ADMIN_SECRET_KEY`:
  - `ADMIN_SECRET_KEY=django-insecure-dev-key-admin-1234567890-abcdefghij`
  - `ADMIN_SECRET_KEY=dummy`
- Docker Compose loaded the last definition (`dummy`), so the admin backend ran with `SECRET_KEY=dummy`.
- The ZB API keys stored in the database were encrypted using a different key. Because the active `SECRET_KEY` changed or was overridden, `decrypt_value` failed and returned the ciphertext.

## Root Cause
The `SystemSetting` encryption logic implicitly depended on the volatile Django `SECRET_KEY` because `SETTINGS_ENCRYPTION_KEY` was neither defined in `.env.staging` nor mapped in `docker-compose.staging.yml`. When `ADMIN_SECRET_KEY` accidentally evaluated to `"dummy"`, it broke the decryption of all previously saved sensitive settings.

## Prevention / Rule
**Guardrail:** Define explicitly decoupled encryption keys for all data-at-rest encryption (e.g., `SETTINGS_ENCRYPTION_KEY`), rather than falling back to `SECRET_KEY`.

A configuration schema validation (like `pydantic-settings` or a startup check) that asserts `SETTINGS_ENCRYPTION_KEY` is set and `SECRET_KEY != "dummy"` would prevent the application from silently starting with degraded encryption.

## Solution

### Immediate Fix
- Removed the duplicate `ADMIN_SECRET_KEY=dummy` definition from `.env.staging`.
- Added an explicit `SETTINGS_ENCRYPTION_KEY` to `.env.staging`.
- Mapped `SETTINGS_ENCRYPTION_KEY` in `docker-compose.staging.yml` for `admin-backend`.
- Restarted `admin-backend` and `payments` services.
- The user was instructed to re-enter the ZB API keys one final time so they encrypt with the new stable key.

```bash
sed -i 's/^ADMIN_SECRET_KEY=dummy//' .env.staging
echo 'SETTINGS_ENCRYPTION_KEY=hbec-stable-settings-encryption-key-1234567890' >> .env.staging
# Added mapping in docker-compose.staging.yml
docker compose -f docker-compose.staging.yml up -d --force-recreate admin-backend payments
```

### Long-term Fix
Update the system settings encryption logic to mandate `SETTINGS_ENCRYPTION_KEY` and refuse to encrypt/decrypt (or throw a loud warning) if it falls back to a dummy key.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
