# Marking smoke test's own seed script never created a StudentProfile, masking as a 401 "auth" failure

**Date:** 2026-10-12
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`), found while running post-deploy verification
**Severity:** Medium (test-tooling bug; no real student was affected)
**Status:** Resolved

## Summary
Running the marking-path smoke test (`tests/uatt`, added by the PR this was
meant to verify) against production after a 17-PR deploy failed immediately
with `subjects: 401` / `"Authentication token is invalid or expired."` — on
a token that had just been issued by a successful login seconds earlier.
Every symptom pointed at the session-revocation/JWT-epoch mechanism
(`SessionAwareJWTAuthentication`, `issued_before()`), which is exactly the
kind of subtle timing bug worth taking seriously. It wasn't that: the
account the test's own `seed-student-user` npm script creates has never had
a `StudentProfile` row, and the curriculum endpoint's deliberate
"rejected token, not no token" check (`token_present_but_rejected`) cannot
tell "profile missing" apart from "profile missing because the real
authenticated student record doesn't exist" — both read as the same 401.

## Symptoms
- `student-marking-smoke.spec.ts`'s `discover()` step failed on
  `GET /api/curriculum/subjects/` with the Bearer token from a login that
  had just succeeded (`POST /api/auth/login/` returned 200 with a token).
- Reproduced identically via raw `curl` outside Playwright, and again
  entirely inside the backend container via `APIRequestFactory` with zero
  network/Caddy/blue-green routing involved — ruling out infrastructure.

## Investigation Steps

### 1. Initial Diagnosis
The error text ("token is invalid or expired") and the fact that this
followed a 17-PR deploy including real security hardening (PR #53's
rate-limit/auth changes) made the session-epoch mechanism the obvious first
suspect.

### 2. Root Cause Analysis
Traced the exact code path: `SubjectListView.get()` calls
`get_student_profile(request)`, and when that's `None` **and** an
`Authorization` header was present, returns 401 by design — this exists
specifically so an authenticated student with a genuinely expired token
gets a 401 (triggering the frontend's refresh flow) rather than silently
falling back to guest-level query-param trust (see the view's own docstring
and `core/middleware.py::token_present_but_rejected`).

Called `SessionAwareJWTAuthentication.authenticate()` directly against the
exact same token — it succeeded, returning the user and valid claims. Also
directly tested `issued_before()` with the token's real `iat` and the
user's real `sessions_revoked_at` (captured in the same request) — it
correctly returned `False` (not revoked). This ruled out the
same-second-boundary race the function's own docstring already accounts
for, and ruled out the epoch mechanism entirely.

### 3. Key Findings
`get_student_profile()` returns `None` for three distinct cases
indistinguishably: no token, wrong role, **or a student with no
`StudentProfile` row**. Checked the test account directly:
```
role: 'student'
has profile: False
```
Real students always get a `StudentProfile` created at signup
(`StudentProfile.objects.create(user=user)` in the signup view). The
`seed-student-user` script in `tests/uatt/package.json` creates the
`CustomUser` row directly via Django shell and never creates the matching
profile — so every account it has ever produced has been missing one.

## Root Cause
`tests/uatt/package.json`'s `seed-student-user` script bypasses the real
signup flow (by design, since it's a one-line fixture seeder) but omitted
the one side effect of signup the curriculum endpoints actually depend on.
A `role='student'` user with no profile is indistinguishable, from
`get_student_profile()`'s return value alone, from a token the
authentication layer genuinely rejected — which is exactly the ambiguity
`token_present_but_rejected()` exists to resolve in the *other* direction
(telling a rejected token apart from no token at all), but it has no way to
also tell "authenticated, no profile" apart from "token rejected" when both
collapse to the same `None`.

## Prevention / Rule
**Guardrail:** any seed/fixture script that creates a user account for a
role the real signup flow gives mandatory related rows (here, `role=student`
implies `StudentProfile`) must create those same rows, or the fixture is not
actually equivalent to a real account and will fail in ways that look like
unrelated bugs (auth, permissions) rather than what they are (bad fixture
data). A short comment in the seed script naming the invariant it must
satisfy would have caught this at review time.

## Solution

### Immediate Fix
Created the missing `StudentProfile` for the existing
`uatt-student@hbec.test` fixture account directly, and confirmed
`GET /api/curriculum/subjects/` returns `200` with no other change.

### Long-term Fix
Updated `seed-student-user` in `tests/uatt/package.json` to also call
`StudentProfile.objects.get_or_create(user=u)`, so every future run of this
script (local dev or production smoke-test provisioning) produces a
genuinely usable account, not just a user row.

### Verification
Re-ran the full marking smoke test against production after the fix:
**4 passed, 1 skipped** (no `synced-without-ids` paper currently exists in
the catalogue — correctly skipped, not failed, per the test's own design).
AI paper, synced-with-ids paper, and admin-published paper all marked
successfully through the real services; every catalogued paper opens.

## Prevention
- [x] Fixture account repaired; smoke test passes end to end
- [x] `seed-student-user` script fixed to create the profile going forward
- [ ] Consider a one-line assertion/comment in each seed script naming the
      invariant real signup guarantees, so a reviewer adding a new seed
      script for a different role catches this class of gap before it ships

## Related Issues
- `reports/HBEC-2026-10-11-docker-containerd-dataroot-migration.md` and the
  17-PR merge report — this was found while running that deploy's
  documented post-deploy verification step (PR #75)

## References
- `STUDENT/hbec_backend/core/middleware.py` (`get_student_profile`,
  `token_present_but_rejected`)
- `STUDENT/hbec_backend/apps/curriculum/views.py` (`SubjectListView`)
- `STUDENT/hbec_backend/apps/accounts/authentication.py`
  (`SessionAwareJWTAuthentication`) — investigated and cleared, not the cause
- `tests/uatt/package.json` (`seed-student-user`)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** ~30 minutes (the epoch-mechanism investigation was
the long pole; the actual fix took two minutes once found)
