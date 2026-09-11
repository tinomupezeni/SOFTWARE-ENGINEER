# Student last_login Never Recorded — Every Student Shows "Never" in Admin's Student List

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Development (found via a ProjectFlow task, root-caused locally)
**Severity:** Medium
**Status:** Resolved

## Summary
A ProjectFlow task ("Last Login — Showing never for all students") led to
finding the same bug class already fixed for admin users earlier this
session (`2026-09-09` entries), but on the Student Backend this time:
neither `StudentLoginView` (email/password) nor `GoogleAuthView` (Google
Sign-In) ever called `update_last_login`, so `User.last_login` stays `NULL`
for every student regardless of how many times they log in.

## Symptoms
Admin's Student Management ("students list", via `apps/internal/views.py`'s
`GET` endpoint, which supports `ordering=last_login`/`-last_login`) shows
"Never" for every student — not a display bug, the field is genuinely never
written.

## Environment Details
- **Server/Host:** Student Backend, all environments (bug is in shared code,
  not environment-specific)
- **Services Affected:** `apps/accounts/views.py` (`StudentLoginView`,
  `GoogleAuthView`), read by `apps/internal/views.py`'s student-listing
  endpoint
- **Time First Observed:** 2026-09-10, surfaced via a ProjectFlow task filed
  earlier and pulled directly via the ProjectFlow API

## Investigation Steps

### 1. Initial Diagnosis
`grep -rn "last_login"` across the Student Backend found it referenced only
in `apps/internal/serializers.py`, `apps/accounts/admin.py` (Django admin
list display), and `apps/internal/views.py`'s ordering allowlist — never
written anywhere.

### 2. Root Cause Analysis
Read both real login entry points in full:
- `StudentLoginView.post()` authenticates via `StudentLoginSerializer`
  (covers email/password login for students, parents, and the shared
  parent→child login path), issues JWTs via `get_tokens_for_user`, and never
  touches `last_login`.
- `GoogleAuthView.post()` (all three branches — existing google_id, email
  link, brand-new user) same gap.
- `get_tokens_for_user` (the shared JWT-issuing helper both views call)
  doesn't touch it either — confirmed there's no other place it could be
  silently happening.

### 3. Key Findings
- Exact same bug shape as the Admin backend's `last_login` fix from
  2026-09-09 (`LoginSerializer.validate()` never called `update_last_login`)
  — same root cause, different service, independently introduced.
- Two separate call sites needed the fix, not one — Google Sign-In is a
  fully independent auth path from the password login view.

## Root Cause
Neither student authentication view ever called Django's
`update_last_login`, so the field was never written regardless of login
volume or method.

## Solution

### Immediate Fix
Added `from django.contrib.auth.models import update_last_login` and a
`update_last_login(None, user)` call in both `StudentLoginView.post()`
(right after the serializer resolves `user`) and `GoogleAuthView.post()`
(right after the user is resolved/created, covering all three branches),
both before token issuance. 5 new tests (`test_last_login.py`): successful
login sets it, repeat login advances it, failed login leaves it untouched,
new-user Google login sets it, repeat Google login advances it.

### Long-term Fix
None needed beyond the fix itself — this is the same pattern already
established for the Admin backend equivalent.

## Prevention
- [x] Fix verified via 5 new tests, plus a full `apps/accounts/tests/` run
      confirming nothing else broke (one unrelated pre-existing failure
      found and separately documented —
      `2026-09-10-parent-signup-error-flattening-keyerror.md`)
- [ ] Worth a quick audit of any other services with their own login flow
      for the same gap, now that it's shown up twice independently

## Related Issues
- Same bug class as `2026-09-01-staging-login-audit-not-recording-last-login.md`
  (Admin backend, resolved 2026-09-09) — that fix did not cover the Student
  Backend, which has entirely separate auth code

## References
- `STUDENT/hbec_backend/apps/accounts/views.py` (`StudentLoginView`, `GoogleAuthView`)
- `STUDENT/hbec_backend/apps/internal/views.py` (the endpoint that surfaced the symptom)
- `STUDENT/hbec_backend/apps/accounts/tests/test_last_login.py` (new)

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session
