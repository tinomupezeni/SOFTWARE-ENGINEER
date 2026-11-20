# School admin password is only ever emailed — and production has no mail transport

**Date:** 2026-11-20
**Project:** HBEC
**Environment:** Production (hbca-vps), source review
**Severity:** High
**Status:** Investigating (three fixes possible, owner decision needed)

## Summary
A school admin's password is generated server-side and delivered in exactly
one way: `send_mail(...)` of the welcome note. In production neither
`hbec-schools-backend-blue` nor `-green` has any `EMAIL_*` variable, so
`settings/base.py` falls back to Django's **console** backend — the password
is printed to container stdout and never reaches anyone. `fail_silently=True`
means nothing surfaces as an error, `create_institution`'s 201 response does
*not* include the password (unlike `create_school_admin`, which does), and
there is no password-reset or change-password endpoint anywhere in the
schools backend or the school dashboard. Net effect: a school added through
the panel has no supported way for its admin to ever log in, even when the
email-case bug (see `Integrations_and_Auth/HBEC-2026-11-20-school-admin-
cannot-login-mixed-case-email.md`) is fixed.

## Symptoms
- Platform admin adds a school, is told "School created successfully!", and
  the school-side form promises "The system will automatically generate a
  secure password" — no password is shown in the panel and no email arrives.
- School admin cannot log in; no self-service recovery exists. The dashboard
  login page's "Need access?" line links to `href="#"` ("Contact HBCA Admin").
- No error anywhere: `send_mail(..., fail_silently=True)` on a console
  backend succeeds.

## Environment Details
- **Server/Host:** `hbca-vps`.
- **Services Affected:** `hbec-schools-backend-blue`, `hbec-schools-backend-green`.
- **Related Components:**
  `SCHOOLS/schools_backend/schools_backend/settings/base.py:141-160`
  (email settings), `institutions/views.py:213-223` (`create_institution`
  welcome mail), `:304-316` (`create_school_admin`, also returns the
  plaintext password in its 201 body),
  `SCHOOLS/school_dashboard/src/routes/login.tsx:120-124` (no recovery link).
- **Time First Observed:** 2026-11-20 (production env audit).

## Investigation Steps

### 1. Initial Diagnosis
Asked why a freshly created school admin could not log in, then checked how
the generated password is handed to a human at all.

```bash
ssh hbca-vps 'docker exec hbec-schools-backend-blue sh -c "env | grep -iE \"EMAIL|SMTP\""'
# NO_EMAIL_ENV   (same for -green)
ssh hbca-vps 'for c in $(docker ps --format "{{.Names}}" | grep -E "^hbec-"); do
  docker logs $c 2>&1 | grep -c "Welcome to HBEC"; done'   # 0 everywhere
```

### 2. Root Cause Analysis
`base.py` derives `EMAIL_USE_SMTP` from the presence of `EMAIL_HOST_USER` +
`EMAIL_HOST_PASSWORD` and defaults `EMAIL_BACKEND` to console when they are
absent. Production sets neither, so the "delivery channel" is stdout — and
the create path has no fallback channel (password not returned) and no later
channel (no reset endpoint).

### 3. Key Findings
- `env | grep -i EMAIL` on both colors: nothing. Console backend, confirmed
  by code, not inferred.
- "Welcome to HBEC" appears in **zero** container logs — consistent with the
  production database having only the seeded `Test` school, i.e. this path
  has never actually run in production; the first real run would silently
  drop the only copy of the credential.
- `create_school_admin` already returns `"password"` in its 201 body for the
  admin panel to display; `create_institution` deliberately does not — the
  two paths that mint the same kind of credential disagree.
- `grep` for `reset|forgot|change-password|new_password` across
  `schools_backend/` and `school_dashboard/src/` → no recovery flow exists.

## Root Cause
Credential delivery for the school-creation path is a single unverified
hop (SMTP with `fail_silently=True`) in an environment where SMTP is not
configured, with no second channel (panel display) and no third channel
(reset).

## Prevention / Rule
**Guardrail:** make the credential visible to the operator who minted it,
independent of mail: `create_institution` returns `password` once in its 201
response, the panel displays it (same UX as "Add school admin" already has),
and a contract test asserts the field is present. Delivery by email then
becomes a convenience, not the only path — so an unconfigured transport can
never again produce an unusable account.

Configuring SMTP without that change would only move the single point of
failure from stdout to a provider; the guardrail is removing the *single*
channel.

## Solution

### Immediate Fix
None yet — awaiting owner decision on which of:
1. **Return the password in the 201 response** + display in the admin panel
   (small, no secrets infra, closes the gap permanently; contract change
   across adminBackend/adminFrontend).
2. **Configure SMTP** for the schools backend in `cd.yml`/compose
   (needs real `EMAIL_HOST_USER`/`EMAIL_HOST_PASSWORD`; delivery to real
   school inboxes still needs `fail_silently` removed or observed).
3. **Add a password-reset flow** (largest; also fixes the *existing*
   inability to ever change a password, which both welcome emails promise).

These are not mutually exclusive; 1 is the one that removes the single
point of failure.

### Long-term Fix
- [ ] Decide/implement option 1 (and 2/3 as follow-ups).
- [ ] Remove or observe `fail_silently=True` on the welcome mail so a mail
  failure is at least logged with `error.*` fields.
- [ ] Consider a readiness/startup log line stating which email backend the
  process is actually using, so an unconfigured transport is visible.

## Prevention
- [ ] Configuration changes needed — SMTP vars in prod env, if option 2.
- [ ] Code changes required — option 1 (and/or 3).
- [ ] Monitoring/alerts to add — log the chosen `EMAIL_BACKEND` at startup.

## Related Issues
- `Integrations_and_Auth/HBEC-2026-11-20-school-admin-cannot-login-mixed-case-email.md`
- `Integrations_and_Auth/HBEC-2026-11-16-school-import-predictable-passwords.md`
  (student-side credential minting in the same service).

## References
- `SCHOOLS/schools_backend/schools_backend/settings/base.py:141-160`.

---

**Resolved By:** opencode (mimo-v2.6-flash-free) — investigation only; fix pending decision
**Time to Resolution:** open
