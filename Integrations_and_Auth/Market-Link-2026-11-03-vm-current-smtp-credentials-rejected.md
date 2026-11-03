# VM Current SMTP Credentials Were Rejected

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Production VM release preflight
**Severity:** High
**Status:** Resolved — deployed in release 34274f0; SMTP acceptance and inbox receipt both verified. See [[Market-Link-2026-11-03-production-smtp-sender-identity-wrong-account]] for a separate, still-open finding that the working account is the wrong sender identity.

## Summary
The VM's current backend `.env` contained Gmail settings, but Gmail rejected SMTP authentication with `EAUTH`. The VM's older `.env.bak-20261006` contained different mail settings that authenticated successfully with the app's Nodemailer Gmail transport.

## Symptoms
- Users reported missing verification and reset emails.
- A direct SMTP authentication check using the current `.env` returned `EAUTH`.

## Environment Details
- **Server/Host:** `agromarket-vm`
- **Services Affected:** Registration verification and password reset email
- **Related Components:** `backend/.env`, `backend/.env.bak-20261006`, `backend/controllers/authController.js`
- **Time First Observed:** 2026-11-03 release preflight

## Investigation Steps

### 1. Initial Diagnosis
Checked key presence without printing values and ran Nodemailer's `verify()` in the newly built backend image with the current settings.

### 2. Root Cause Analysis
The current account failed authentication even when display spaces were removed from its app password. The backup contained a different account and password; it authenticated with the same transport.

### 3. Key Findings
- Current account: `EAUTH`.
- Backup account: SMTP authentication succeeded with its password as stored.
- The existing running backend container did not have email environment keys, so presence in the host file did not mean it was active in the container.
- No credential values were printed or copied off the VM.

## Root Cause
The active VM file held unusable SMTP settings, and the old Compose file did not load that file into the backend container.

## Prevention / Rule
**Guardrail:** Validate effective container mail configuration and SMTP authentication before promotion; checking only file presence is insufficient.

This catches invalid credentials and Compose environment drift before users request email links.

## Solution

### Immediate Fix
Copied only the two working mail settings from the VM backup into the staged release `.env`, retaining all other current settings. The release Compose config loads this file; its SMTP authentication check passed.

### Long-term Fix
Add an operator-safe mail health check and verify a delivered message during release smoke testing.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `DevOps_and_Infrastructure/Market-Link-2026-11-03-vm-mail-url-settings-missing.md`
- `Integrations_and_Auth/Market-Link-2026-11-03-password-reset-email-url-and-config.md`

## References
- `backend/controllers/authController.js`
- `docker-compose.yml`

---

**Resolved By:** Codex (staged release configuration)
**Time to Resolution:** Same work session; live deployment pending

## Verification

- Nodemailer `verify()` passed using the staged release `.env` in the new backend image.
- Inbox receipt and live application email endpoints remain to be checked after deployment.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.

## Follow-up QA pass closing the open gap (2026-11-03, same day)

A second QA pass against live production confirmed the remaining open item:
registered a real buyer (location + business name, no ID photo field) and a
real farmer against `agromarketing.co.zw`, both received verification email,
and the user confirmed inbox receipt directly. The farmer account was
verified, logged in, created a product with an uploaded image via the live
API, and the returned image URL was fetched successfully (HTTP 200). A
password-reset request for the test buyer also returned success. All test
users and the test product were deleted afterward; user/product counts
returned to the pre-test baseline (54 users, 16 products).

This closes "inbox receipt pending" — delivery itself works. It also
surfaced that the authenticating account is the wrong sender identity; see
[[Market-Link-2026-11-03-production-smtp-sender-identity-wrong-account]].
