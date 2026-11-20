# 2026-11-20 — school-admin login fix + first CI job for the schools service

**What changed**
- `SCHOOLS/schools_backend/institutions/views.py` — `create_institution`
  now normalizes the school email (`strip().lower()`) so the username it
  mints matches what `login()` looks up; previously any uppercase letter
  made that school admin permanently unauthenticatable (401).
- `SCHOOLS/schools_backend/institutions/tests.py` — added
  `InstitutionCreateLoginTests` (signed create → login round-trip for
  as-typed and lowercased email, case-insensitive duplicate check); moved
  three mid-file imports to the top so `ruff check` passes.
- `.github/workflows/ci.yml` — added the `schools-backend-tests` job
  (ruff + `manage.py test` on in-memory sqlite) plus its `changes` filter
  and output, and listed it in `deployable.needs` and `ci-success.needs`.
  The schools service had no CI job of any kind before this.

**Why it matters architecturally:** a whole deployed service (schools
backend, on the public `school.hbca.tech` path) was outside the
`deployable` gate that `wait-for-ci.sh` enforces, so schools changes
shipped on master without a single automated test. It is now inside the
gate; `deployable` is no longer a complete list of services without it.

**Memory files updated:** `MAIN.md` (filled in — was an unfilled template;
records live blue/green topology and both 2026-11-20 findings),
`decisions/authentication.md` (two entries: the split admin/school
credential systems, and the email-only credential delivery decision marked
as a known gap).

**Not done:** neither fix is committed to HBEC or deployed to a live
colour (blue is still `sha-4b4d5ae`, green `sha-1daf513`).
