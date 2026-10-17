# TESC main account credential seed

**Date:** 2026-10-17
**Project:** TESC
**Type:** Account Provisioning
**Status:** Completed

## Summary
Reset the requested production main-app account password for the existing
`mupezeni2001@gmail.com` user and verified that the account remains active and
can begin the normal OTP login flow.

## Context / Trigger
The user requested production credentials for the Scalareye / Zimbabwe Human
Capital Planning and Skills Development account.

## Scope
Included the existing main-app user identified by the requested email,
password reset, account-state verification, and a public login smoke check.
No institution record, role, permission, username, or profile identity was
created or changed because the email already belonged to an existing global
user.

## Method
Inspected the production user and institution records first. The email was
already associated with an active global `CustomUser` and an existing
migrated role. Updated only the password and verified it through Django's
password hash check, then submitted a login request without exposing tokens.

## Decisions & Findings
- The requested email already existed as production user `id=5`.
- The account was not linked to an institution.
- Existing role and profile data were preserved to avoid changing permissions
  for an existing user.
- The public login endpoint returned HTTP 200 with `requires_otp`, confirming
  the password was accepted and the normal OTP step was reached.

## Changes Made
- Updated the password hash for the existing production user.
- Ensured the account remained active and did not require a forced password
  change.

## Verification
- Django `check_password` returned true for the requested password.
- Account remained active.
- Public `POST /api/users/token/` returned HTTP 200 and `requires_otp`.
- No access or refresh token contents were logged or recorded.

## Follow-ups / Deferred
- Complete OTP verification through the normal email delivery flow when the
  user signs in.
- Rotate the credential if it is shared outside the intended account owner.

## References
- Production `users.CustomUser`
- TESC main authentication endpoint `/api/users/token/`

---

**Completed By:** Copilot
**Duration:** Same session
