# Payment Settings Encryption Key Drift

**Date:** 2026-09-19
**Project:** HBEC
**Area:** Backend and API

## Issue Description
Staging ZB Bank payments failed with a `401 Unauthorized` despite having the exact same credentials as Production in the database.

## Root Cause
The `admin-backend`'s `system_settings` app encrypts sensitive payment gateway credentials (like `zbApiKey`) before saving them to the database. In `apps/system_settings/views.py`, the encryption/decryption functions attempt to use `django_settings.SETTINGS_ENCRYPTION_KEY`. Because this variable is not defined in `settings.py`, it falls back to using the Django `SECRET_KEY`.

When the production database was copied to staging, the encrypted credentials were also copied. However, because the staging environment uses a different Django `SECRET_KEY`, the staging `admin-backend` failed to decrypt them. 

Additionally, the `decrypt_value()` function silently catches any exception and returns the raw ciphertext (`enc::...`). As a result, the `payments` container received `enc::...` instead of the actual API keys, passing them to ZB Bank and triggering the 401.

## Resolution (Recommended)
This is documented as a root-cause finding. The immediate fix is to simply re-save the payment credentials in the staging admin dashboard so they are encrypted with the staging `SECRET_KEY`. 

For a long-term fix, the `system_settings` app should be updated to use a dedicated encryption key (like `MODEL_SETTINGS_ENCRYPTION_KEY`) rather than overloading the Django `SECRET_KEY`, and `decrypt_value` should log an error instead of silently returning ciphertext when decryption fails.

**Resolved By:** Antigravity
