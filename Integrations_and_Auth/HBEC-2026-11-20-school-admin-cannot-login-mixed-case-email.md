# School admin added through the panel can never log in (email case)

**Date:** 2026-11-20
**Project:** HBEC
**Environment:** Production configuration (reproduced in-process against the real views)
**Severity:** High
**Status:** Resolved (code fix + regression tests + CI gate; not yet deployed to a live color)

## Summary
Adding a school through admin.hbca.tech mints a login the school admin can
never use: `create_institution` stores `auth_user.username` exactly as the
platform admin typed the school email, while `login()` lowercases its input
before `authenticate()`. Any uppercase letter anywhere in the email (typical
hand-typed values like `Head@Vainona.ac.zw`) therefore produces an account
that returns 401 "Invalid credentials" both as typed and lowercased, with the
correct password.

## Symptoms
- School admin created from the admin panel cannot log in at
  `https://school.hbca.tech/login`; `401 {"error": "Invalid credentials"}`.
- Retyping the email in lowercase does not help — the lookup key never matches.
- Same request succeeds when the email happens to be typed entirely lowercase,
  so the bug looks like "a password problem" rather than a data problem.
- Production schools backend shows `POST /api/v1/auth/login/` → 401 on
  2026-11-17 12:14 and 2026-11-18 07:42.

## Environment Details
- **Server/Host:** `hbca-vps` (gpu-ndime), Caddy gateway `hbec-gateway`.
- **Services Affected:** `hbec-schools-backend-blue`
  (`ghcr.io/rest-creator/hbec-schools-backend:sha-4b4d5ae`, the color
  `school.hbca.tech` and `admin.hbca.tech` both route to), schools backend
  green (staging domains) — identical code path.
- **Related Components:**
  `SCHOOLS/schools_backend/institutions/views.py` (`create_institution`,
  `create_school_admin`, `login`), `ADMIN/adminBackend/apps/
  schools_management/`, `ADMIN/adminFrontend/.../SchoolFormPage.tsx`.
- **Time First Observed:** reported 2026-11-20; the underlying asymmetry has
  existed since `create_institution` was written.

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the running topology first: `Caddyfile` (generated,
`active_color=blue`) routes `school.hbca.tech` → `hbec-schools-backend-blue`
and `admin.hbca.tech` → `hbec-admin-frontend-blue` → `admin-backend-blue` →
`schools-backend-blue`. All colors share one database (`main-pgbouncer`
resolves `*` to host `postgres` = `hbec-postgres`, alias `postgres` on
`hbec_db-net`), so this was not a two-database drift.

```bash
ssh hbca-vps 'docker exec hbec-gateway sh -c "cat /etc/caddy/Caddyfile"'
ssh hbca-vps 'docker exec hbec-postgres psql -U hbec -d hbec_schools \
  -c "SELECT id, username, email, is_active FROM auth_user ORDER BY date_joined DESC;"'
```

### 2. Root Cause Analysis
Read both sides of the contract in the *deployed* container (not just the
checkout), then drove the real views in-process with the real HMAC gate:
an HMAC-v2-signed `POST /api/v1/institutions/create/` followed by
`POST /api/v1/auth/login/`, three email-case variants.

```python
# schools_backend/institutions/views.py
# create_institution: email = data.get("email")            # verbatim
email = (data.get("email") or "").strip().lower()          # login()
user = authenticate(request, username=email, password=password)  # exact match
```

### 3. Key Findings
- `create_school_admin` (the "add a principal to an existing school" path)
  *already* did `.strip().lower()` — only the school-creation path was wrong,
  which is why one admin flow works and the other silently doesn't.
- Duplicate-email detection in `create_institution` used the same verbatim
  value, so `Dup@x` / `dup@x` could both be created.
- Production's `hbec_schools` contains exactly one institution
  (`Test`, 2026-10-14) and one school admin, and no
  `institutions/create` request appears in any admin-frontend, admin-backend
  or schools-backend log — i.e. the school the report referred to never
  landed in the production database. Credential delivery is a separate,
  also-open problem (see
  `DevOps_and_Infrastructure/HBEC-2026-11-20-school-admin-password-never-delivered.md`).

## Root Cause
Two code paths disagree about the login key's canonical form:
`login()` normalizes to lowercase, `create_institution()` does not, so
`django.contrib.auth.backends.ModelBackend` — which does an exact username
lookup — never finds the user the creation path wrote.

## Prevention / Rule
**Guardrail:** `InstitutionCreateLoginTests`
(`SCHOOLS/schools_backend/institutions/tests.py`) — a signed
create-school → read the generated password → login round-trip asserted
**twice**, once with the email as typed and once lowercased, plus a
case-insensitive duplicate-email check; run by the new
`schools-backend-tests` CI job (`.github/workflows/ci.yml`), which is in
`deployable.needs`, so a push to master cannot ship a schools change that
regresses it.

The schools backend previously had **no CI job at all**, which is how this
survived: the guardrail had to be the job, not only the test.

## Solution

### Immediate Fix
`SCHOOLS/schools_backend/institutions/views.py` (`create_institution`):
normalize the email exactly like `login()` and `create_school_admin()` do
(`strip().lower()`), so the username, `email` and `contact_email` fields all
agree with the lookup key.

```bash
python manage.py test institutions --settings=schools_backend.settings.test   # 29 passed
ruff check institutions schools_backend                                        # clean
```

### Long-term Fix
- `InstitutionCreateLoginTests` regression tests (added; verified red with
  the fix reverted, green with it applied).
- New `schools-backend-tests` CI job wired into `changes`, `deployable` and
  `ci-success`; `ruff check` there too (fixed the three pre-existing E402s
  in `tests.py` that would have made it fail on day one).
- No data migration was written: production's only school admin
  (`admin@school.com`) is already lowercase, and no mixed-case username row
  exists in `hbec_schools`. If a broken row is ever found elsewhere, fix it
  with `UPDATE auth_user SET username = lower(username) WHERE username <>
  lower(username);` alongside the code fix.

## Prevention
- [x] Code changes required — normalization in `create_institution`.
- [x] Tests — `InstitutionCreateLoginTests` (2 tests, red/green verified).
- [x] CI gate — `schools-backend-tests` job, required by `deployable`.
- [ ] Deploy: the fix is not in either live color yet (blue = `sha-4b4d5ae`,
  green = `sha-1daf513`, both built before this change).

## Related Issues
- `DevOps_and_Infrastructure/HBEC-2026-11-20-school-admin-password-never-delivered.md`
  — even a correctly-cased account cannot be logged into until the operator
  can obtain the generated password.
- `Integrations_and_Auth/HBEC-2026-11-16-school-import-predictable-passwords.md`
  — same file, other credential-minting path.

## References
- `SCHOOLS/schools_backend/institutions/views.py:70` (login), `:192`
  (create_institution email), `:281` (create_school_admin, already normalized).
- `SCHOOLS/schools_backend/institutions/tests.py` → `InstitutionCreateLoginTests`.

---

**Resolved By:** opencode (mimo-v2.6-flash-free)
**Time to Resolution:** ~1 session (reproduce → root cause → fix → CI gate)
