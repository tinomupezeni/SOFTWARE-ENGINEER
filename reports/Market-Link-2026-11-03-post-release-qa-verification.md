# Post-release QA verification of release 34274f0

**Date:** 2026-11-03
**Project:** Market-Link
**Type:** Audit (post-deployment verification)
**Status:** Completed

## Summary
Codex deployed release `34274f0` to production (`agromarketing.co.zw` /
`agromarket-vm`) to fix five reported issues: farmers unable to add
products, product images not showing, buyer signup asking for an ID photo
URL instead of location, verification emails not arriving, and password
reset emails not arriving. Codex's own write-up left several things
unverified or open ("inbox receipt was not independently checked", several
`npm audit` advisories, frontend running the dev server in production,
Mongo exposed on all interfaces). This session independently re-tested the
live deployment end to end, closed the inbox-receipt gap, and surfaced one
new finding Codex's work did not catch: the production mail sender is the
wrong account identity.

## Context / Trigger
The user asked for the deployed app to be tested thoroughly after Codex's
work, pasting Codex's own summary as the starting context.

## Scope
Covered: local regression/unit test suites (backend + frontend), live
production smoke testing of all five originally-reported user flows
(buyer registration with location, farmer registration, farmer login,
product creation with image upload, image retrieval, password-reset
request), and git/deployment state parity (local vs. `origin/main` vs. the
running VM containers).

Explicitly excluded: remediating the `npm audit` advisories, the frontend
dev-server-in-production issue, and the open MongoDB port exposure that
Codex's report flagged as deferred — these were left as-is per Codex's
"open findings for the next agent" list and were not back in scope for this
verification pass.

## Method
Read-only checks first (git log/status parity, `docker ps`/`compose ps` on
the VM, public HTTP smoke checks) before any mutating test. Mutating tests
(real user registration, real product creation with a real image upload,
a real password-reset request) were run only after explicit user
confirmation to test against live production, using disposable
`+qabuyer<timestamp>@thuthuka.tech` / `+qafarmer<timestamp>@thuthuka.tech`
addresses so results could be attributed and cleaned up afterward. Email
delivery was confirmed by asking the user to check their actual inbox,
since no tool here can read it directly. All test users and the test
product were deleted after verification, and user/product counts were
confirmed back to the pre-test baseline (54 users, 16 products).

## Decisions & Findings
- All five originally reported issues are fixed and working in production:
  buyer registration now requires `farmLocation` + `businessName` with no ID
  photo field; farmer registration/login/product-creation-with-image all
  succeeded live; uploaded and pre-existing product images both resolve via
  `/uploads/...` and `/api/uploads/...`; verification and password-reset
  emails are both sent and received.
- Local test suites pass cleanly: backend `npm run test:flows` 7/7, frontend
  `npm test` 3/3.
- Git and deployment state are consistent: local `main`, `origin/main`, and
  the VM's running containers are all at `34274f0`.
- New finding (not in Codex's report): production authenticates as
  `manziniemmanuel0@gmail.com`, a personal Gmail account, not the intended
  `marketlink242@gmail.com` business account. A full search of the VM
  (`/home/user/Documents`, `/home/user/Downloads`, every old/archived
  checkout) found no `marketlink242` credential anywhere — it was never
  provisioned on this VM. Logged separately as
  `Integrations_and_Auth/Market-Link-2026-11-03-production-smtp-sender-identity-wrong-account.md`.

## Changes Made
No application code was changed in this session. Database changes were
limited to test fixtures created and then deleted (2 users, 1 product).

## Verification
- `backend`: `npm run test:flows` → 7 passed, 0 failed.
- `frontend`: `CI=true npm test -- --watchAll=false` → 3 passed, 0 failed.
- Live: buyer registration (201, `emailSent: true`), farmer registration
  (201, `emailSent: true`), user-confirmed inbox receipt of both emails,
  farmer login after email verification (200), product creation with image
  upload (201), uploaded image fetch (200), password-reset request (200),
  product delete cleanup (200), DB counts restored to 54 users / 16
  products.

## Follow-ups / Deferred
- Obtain a `marketlink242@gmail.com` Gmail App Password from the user and
  switch production's `EMAIL_USERNAME`/`EMAIL_PASSWORD` to it; recreate
  `marketlink_backend`; re-verify SMTP auth and inbox receipt.
- Codex's other open findings remain open and were not addressed here:
  `npm audit` advisories (critical `proxy-addr`, high `nodemailer`/`axios`/
  `multer`), frontend production image running `react-scripts start`
  instead of a static build, MongoDB published on all host interfaces with
  no auth tested from outside, and the untracked VM-specific
  `compose.production.yml` override.
- Minor, not from this release: `deleteProduct` does not remove the
  uploaded image file from disk, leaving an orphaned file after the test
  product's deletion (consistent with pre-existing orphaned files already
  present in `backend/uploads/`). Not reported as a bug entry since it is
  pre-existing behavior, not a regression from `34274f0`.

## References
- `Integrations_and_Auth/Market-Link-2026-11-03-vm-current-smtp-credentials-rejected.md` (updated with this session's verification)
- `Integrations_and_Auth/Market-Link-2026-11-03-production-smtp-sender-identity-wrong-account.md` (new)
- `backend/controllers/authController.js`, `backend/routes/productRoutes.js`

---

**Completed By:** Claude (QA verification pass)
**Duration:** Single session, 2026-11-03
