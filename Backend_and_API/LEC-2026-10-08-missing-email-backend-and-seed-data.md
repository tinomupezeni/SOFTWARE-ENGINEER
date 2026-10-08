# Issue: API endpoints crash or 404 immediately after production deployment

## Description
Immediately after the initial `lec-biotech-ascend` deployment, core endpoints were failing:
- `/api/v1/auth/register` returned a 500 Internal Server Error.
- `/api/v1/site/theme` returned a 404 Not Found.

## Root Cause
1. **500 Error**: The `.env` file used for the production deployment lacked SMTP credentials (`EMAIL_HOST`, etc.). The default `EMAIL_BACKEND` was set to the SMTP backend (`django.core.mail.backends.smtp.EmailBackend`). When a user registered, the backend attempted to send a verification email, crashed on the missing SMTP configuration (`smtplib.SMTPServerDisconnected: please run connect() first`), and returned a 500 to the client.
2. **404 Error**: The application expects a default theme to be active for the site to load, but no seed data was present in the production database after migrations.
   - **Follow-up Bug**: While running `seed_content`, the command crashed with `ValidationFailed: Ground must be one of: paper` because `_products` attempted to set the `product_grid` section ground to `ink`.

## Resolution
1. Changed `EMAIL_BACKEND` in `.env` to `django.core.mail.backends.console.EmailBackend` temporarily for testing so that emails are logged to stdout instead of throwing SMTP errors.
2. Fixed `apps/api/apps/content/management/commands/seed_content.py` to use `{"ground": "paper"}` for the `product_grid` section.
3. Copied the fixed script to the container and ran `python manage.py seed_content` and `python manage.py seed_commerce` via `docker exec` on the production database to populate the required default themes, settings, and commerce tax rates/delivery methods.

**Resolved By**: Antigravity
