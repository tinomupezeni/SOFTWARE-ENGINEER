# Production SMTP sender uses wrong account identity

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Production
**Severity:** Medium
**Status:** Investigating (credential not found on VM)

## Summary
Release `34274f0` sends all verification and password-reset email from
`manziniemmanuel0@gmail.com`, a personal Gmail account, instead of the
intended business sender `marketlink242@gmail.com`. Email delivery itself
works end to end (confirmed by live test and by inbox receipt), but the
sender identity is wrong.

## Symptoms
- Live QA registration test sent verification mail successfully; the user
  confirmed receipt but flagged the From address as
  `manziniemmanuel0@gmail.com` rather than `marketlink242@gmail.com`.

## Environment Details
- **Server/Host:** `agromarket-vm`, `/home/user/Documents/agromarket/backend/.env`
- **Services Affected:** Registration verification email, password reset email
- **Related Components:** `backend/controllers/authController.js` (`sendEmail`), `backend/.env`
- **Time First Observed:** 2026-11-03, during post-deployment QA of release `34274f0`

## Investigation Steps

### 1. Initial Diagnosis
Confirmed `EMAIL_USERNAME=manziniemmanuel0@gmail.com` in the live
`backend/.env` on the VM.

### 2. Root Cause Analysis
Checked `backend/.env.bak-20261006` (the backup Codex sourced working
credentials from during the `34274f0` release, per
[[Market-Link-2026-11-03-vm-current-smtp-credentials-rejected]]) — it also
holds `manziniemmanuel0@gmail.com`, confirming the personal account was
already in use before this release, not newly introduced by it.

### 3. Key Findings
- `grep -rl "marketlink242" /home/user/Documents /home/user/Downloads` on the
  VM, across every checkout including the stale/archived ones, returned no
  matches — no `marketlink242@gmail.com` app password or config exists
  anywhere on the VM.
- The release process picked whichever Gmail account's app password actually
  authenticated (`manziniemmanuel0@gmail.com`), without confirming it was the
  intended business sender identity.

## Root Cause
Nobody has ever stored working `marketlink242@gmail.com` SMTP credentials on
this VM; the personal Gmail account is a working substitute, not a
deliberate choice, and persisted silently through the `34274f0` release
because the release's mail-config check validated only that *some* account
authenticated, not that it was the *correct* one.

## Prevention / Rule
**Guardrail:** Add an approved-sender check to release smoke testing — assert
the live `EMAIL_USERNAME` equals a declared expected value, not merely that
SMTP auth succeeds. Mirrors the guardrail already recommended in
[[TESC-2026-10-17-production-smtp-sender-drift]] for the same class of drift.

## Solution

### Immediate Fix
None yet — no `marketlink242@gmail.com` app password is available on the VM
or in this repo. Awaiting the business owner to generate a Gmail App Password
for that account.

### Long-term Fix
Once provided, update `backend/.env` on the VM with the `marketlink242`
credentials, recreate `marketlink_backend`, and re-verify SMTP auth +
inbox receipt before closing this out.

## Prevention
- [ ] Configuration changes needed (pending credential)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- [[Market-Link-2026-11-03-vm-current-smtp-credentials-rejected]]
- `TESC-2026-10-17-production-smtp-sender-drift.md` (same class of issue, different project)

## References
- `backend/controllers/authController.js`
- `backend/.env`, `backend/.env.bak-20261006`

---

**Resolved By:** Unresolved — pending `marketlink242@gmail.com` app password from user
**Time to Resolution:** N/A
