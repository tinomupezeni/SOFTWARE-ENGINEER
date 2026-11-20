# Schools backend has no /health/ready at all — only /health/live

**Date:** 2026-11-20
**Project:** HBEC
**Environment:** Production (both colours), source review
**Severity:** Medium
**Status:** Open (found during verification of the 2026-11-20 green deploy)

## Summary
`SCHOOLS/schools_backend` registers only `health/live/`; requesting
`/health/ready/` returns **404 on both live colours** (blue `sha-4b4d5ae`,
green `sha-8e93138`). Every other Python service in the repo
(`STUDENT/hbec_backend`, `ADMIN/adminBackend`, `AGENTIC_HARNESS`) exposes
both, and the repo's own `AGENTS.md` requires "distinct `/health/live` and
`/health/ready` check pathways" with readiness executing dependencies under
a **2.0s maximum** timeout. The schools service has no dependency-checking
readiness path at all: its compose healthcheck hits `/health/live/`
(`docker-compose.production.yml`, `test: ... urlopen('http://localhost:8000
/health/live/')`), which only proves the process answers, never that
Postgres is reachable.

## Symptoms
- `GET /health/ready/` on the schools backend → 404 (both colours).
- No observable user symptom: a schools backend that cannot reach the
  database still reports "healthy" to Docker, so `--wait` during a deploy
  and the color-verification gates can pass on a service that is actually
  unable to serve logins.

## Environment Details
- **Server/Host:** `hbca-vps`.
- **Services Affected:** `hbec-schools-backend-blue`, `hbec-schools-backend-green`.
- **Related Components:**
  `SCHOOLS/schools_backend/schools_backend/urls.py` (only
  `health/live/` registered), `institutions/health.py`,
  `docker-compose.production.yml` schools-backend healthcheck,
  `.github/workflows/ci.yml` (no schools job existed before 2026-11-20).
- **Time First Observed:** 2026-11-20, while probing the green deploy.

## Investigation Steps

### 1. Initial Diagnosis
Post-deploy verification of `sha-8e93138` on green: probe both health
paths directly inside the container.

```bash
docker exec -i hbec-schools-backend-green python   # urllib probe
# /health/live/  200  0.01s  {"status": "alive", ...}
# /health/ready/ HTTPError (404)
```

### 2. Root Cause Analysis
`urls.py` wires only `LiveHealthCheckView`; no readiness view was ever
written for this service (its `institutions/health.py` has no ready
class), and the compose healthcheck was pointed at `/health/live/` — so
nothing anywhere has ever asked this service whether its database is up.

### 3. Key Findings
- Admin and student backends have a `ReadyHealthCheckView` that runs
  `SELECT 1` and returns 503 + `checks.database` on failure; the schools
  service has no equivalent.
- `docker-compose.production.yml`'s schools-backend healthcheck therefore
  cannot fail for a database reason — a hardening gap in exactly the gate
  `manual-deploy-color.sh` relies on.
- The schools service was the one service with **no CI job** before
  2026-11-20, which is consistent: nothing has been checking it.

## Root Cause
The readiness endpoint required by the repo's telemetry standard was never
implemented for this service, and the compose healthcheck was written to
the endpoint that did exist instead of the one that should.

## Prevention / Rule
**Guardrail:** a test in `institutions/tests.py` asserting
`GET /health/ready/` returns 200 with a `checks.database` entry **and**
that a forced DB failure returns 503 — run by the new
`schools-backend-tests` CI job — plus pointing the compose healthcheck at
`/health/ready/`. The compose half is what makes it operational: with the
healthcheck on `ready`, `--wait` and both deploy gates stop passing a
schools backend that cannot serve logins.

## Solution

### Immediate Fix
None yet — discovered after the 2026-11-20 deploy of `sha-8e93138`.

### Long-term Fix
- [ ] Add `ReadyHealthCheckView` to
  `SCHOOLS/schools_backend/institutions/health.py` (DB probe with the
  2.0s bound from `AGENTS.md`), register `health/ready/` in
  `schools_backend/urls.py`.
- [ ] Point the schools-backend healthcheck in
  `docker-compose.production.yml` at `/health/ready/`.
- [ ] Regression test (guardrail above).

## Prevention
- [ ] Code changes required — view + route + compose healthcheck + test.
- [ ] Monitoring/alerts to add — none beyond the healthcheck itself.

## Related Issues
- `DevOps_and_Infrastructure/HBEC-2026-11-20-school-admin-password-never-delivered.md`
  (same service, found in the same session).
- `Integrations_and_Auth/HBEC-2026-11-20-school-admin-cannot-login-mixed-case-email.md`.

## References
- `SCHOOLS/schools_backend/schools_backend/urls.py`,
  `ADMIN/adminBackend/core/health.py:21` (the pattern to copy),
  `AGENTS.md` "Health Checks".

---

**Resolved By:** opencode (mimo-v2.6-flash-free) — investigation only; fix open
**Time to Resolution:** open
