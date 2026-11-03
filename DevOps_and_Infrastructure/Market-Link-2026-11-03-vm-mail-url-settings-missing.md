# Production VM Mail Credentials Present but Public Link URLs Missing

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Production VM read-only inspection
**Severity:** High
**Status:** Resolved — inbox receipt confirmed 2026-11-03 in post-release QA (`reports/Market-Link-2026-11-03-post-release-qa-verification.md`)

## Summary
The `agromarket-vm` backend `.env` has non-placeholder `EMAIL_USERNAME` and `EMAIL_PASSWORD`, but lacks `FRONTEND_URL` and `PUBLIC_API_URL`. The deployed reset code falls back to a domain without a scheme; verification links derive from request host. The VM file sets `NODE_ENV=development`.

## Symptoms
- Users reported missing verification and password-reset email links.
- A reset email could contain a link starting with `agromarketing.co.zw/` without `https://`.

## Environment Details
- **Server/Host:** `agromarket-vm`, `/home/user/Documents/agromarket`
- **Services Affected:** Backend email flows and frontend links
- **Related Components:** `backend/.env`, `backend/controllers/authController.js`, `docker-compose.yml`
- **Time First Observed:** 2026-11-03 SSH inspection

## Investigation Steps

### 1. Initial Diagnosis
Compared deployed commit and working tree, checked the API status, and inspected only the presence and placeholder status of mail settings. Credential values were not printed.

### 2. Root Cause Analysis
The deployed controller uses Gmail via Nodemailer and the `EMAIL_USERNAME`/`EMAIL_PASSWORD` variables. Both are present and non-placeholder; public URL variables are absent. The deployed checkout is at `ae2cfbc` with uncommitted changes, and Docker inspection requires sudo authentication.

```bash
ssh -F /home/shadowe/.ssh/config agromarket-vm git -C /home/user/Documents/agromarket status --short
ssh -F /home/shadowe/.ssh/config agromarket-vm curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:5001/
```

### 3. Key Findings
- Backend root returned HTTP 200; protected `/api/auth/me` returned HTTP 401 without credentials.
- Mail credentials exist but delivery to an inbox was not tested.
- `FRONTEND_URL` and `PUBLIC_API_URL` are missing from the deployed `.env`.
- Docker container identity could not be inspected without a sudo password.

## Root Cause
The live mail account was configured, but public link origin settings were omitted; fallback construction produced unreliable URLs. The VM also runs with `NODE_ENV=development` in its `.env`.

## Prevention / Rule
**Guardrail:** Production deployment must fail unless mail credentials are present and the effective frontend and API origins are public HTTPS URLs; inspect only presence and non-secret fingerprints during release review.

This catches the missing URL configuration without exposing credentials.

## Solution

### Immediate Fix
The local Compose configuration now loads the existing backend `.env`, sets `NODE_ENV=production`, and defaults both public URL settings to `https://agromarketing.co.zw`. The existing mail account remains in the VM `.env`; no secret was copied. The VM was not modified.

### Long-term Fix
Promote a reviewed artifact after reconciling the VM's uncommitted work, then verify delivery and both links with a real recipient.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `Integrations_and_Auth/Market-Link-2026-11-03-verification-email-failure-hidden.md`
- `Integrations_and_Auth/Market-Link-2026-11-03-password-reset-email-url-and-config.md`
- `DevOps_and_Infrastructure/Market-Link-2026-10-06-vm-uncommitted-production-hotfixes.md`

## References
- `docker-compose.yml`
- `backend/controllers/authController.js`
- `README.md`

---

**Resolved By:** Codex (local configuration)
**Time to Resolution:** Deployment pending

## Verification

- Local API tests verify HTTPS link generation and missing configuration behavior.
- Live SMTP delivery and post-deployment links remain unverified.

## Follow-up from release preflight

Presence of `EMAIL_USERNAME` and `EMAIL_PASSWORD` in the current VM `.env` did not imply working delivery: Nodemailer authentication returned `EAUTH`. The VM backup contains different working mail settings, now staged for release. See `Integrations_and_Auth/Market-Link-2026-11-03-vm-current-smtp-credentials-rejected.md`.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
