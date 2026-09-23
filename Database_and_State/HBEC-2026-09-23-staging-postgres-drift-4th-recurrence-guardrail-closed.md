# Staging Postgres Password Drift — 4th Recurrence, Root-Caused to a Same-Day Misdiagnosis, Guardrail Gap Finally Closed

**Date:** 2026-09-23
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved — live drift fixed and verified; the detection gap
that let this recur three times is now closed

## Summary
Deploying four unrelated commits to staging (a cross-service system-error
logging feature) recreated `postgres-staging`/`main-pgbouncer-staging` as
dependencies, which immediately put `student-backend-staging` and
`admin-backend-staging` into a `FATAL: password authentication failed for
user "hbec"` crash loop (~30 restarts each), with `litellm-staging`
crash-looping on the same root cause. This is the exact symptom of
`HBEC-2026-09-09-staging-postgres-secret-drift-crash-loop.md` and
`HBEC-2026-09-20-staging-postgres-password-drift.md` — a **fourth**
occurrence of the same failure class on the same staging database.

## Symptoms
- `student-backend-staging` / `admin-backend-staging`:
  `django.db.utils.OperationalError: ... FATAL: password authentication
  failed for user "hbec"`, crash-looping (~30 restarts each within
  minutes).
- `litellm-staging`: `httpx.ConnectError: All connection attempts failed`
  from its Prisma engine, crash-looping.
- `postgres-staging` itself: `FATAL: password authentication failed for
  user "hbec"` logged on every connection attempt from every dependent
  service.

## Environment Details
- **Server/Host:** `hbca-vps`, staging only (`/home/winstontino/HBEC`)
- **Services Affected:** `hbec-postgres-staging`, `hbec-main-pgbouncer-staging`,
  `hbec-student-backend-staging`, `hbec-admin-backend-staging`,
  `hbec-litellm-staging`
- **Time First Observed:** 2026-09-23, ~18:17 UTC, immediately after
  `postgres-staging`/`main-pgbouncer-staging` were recreated as
  dependencies of an unrelated multi-service deploy

## Investigation Steps

### 1. Initial Diagnosis
`docker logs hbec-student-backend-staging` and `hbec-postgres-staging`
both showed the identical `FATAL: password authentication failed for user
"hbec"` immediately after the containers restarted. Nothing in the four
deployed commits (all Django/FastAPI application code) touches database
credentials.

### 2. Root Cause Analysis
Checked whether `.env.staging` and the docker secret it should match had
drifted, the way they had on 2026-09-09:
```bash
sha256sum docker/secrets/pg_password.txt
grep '^POSTGRES_PASSWORD=' .env.staging | ...  # hashed the value, not printed
```
They matched exactly — no config-level drift this time. But a real
authentication test over the actual service network (never
`localhost`/`127.0.0.1`, which `pg_hba.conf` trusts unconditionally here —
the exact false-positive the 2026-09-09 investigation already warned
about) still failed:
```bash
docker run --rm --network hbec-staging_db-net \
  -e PGPASSWORD=$(cat docker/secrets/pg_password.txt) \
  postgres:16-alpine psql -h postgres -U hbec -d hbec_litellm -c 'SELECT 1;'
# FATAL: password authentication failed for user "hbec"
```
This means the *config* was internally consistent, but the *live database
role* held a third, different password. Checked the dev-log repo for
prior occurrences and found a **same-day** entry,
`Database_and_State/HBEC-2026-09-23-staging-postgres-password-drift.md`
(filed by a different agent, "Antigravity"), whose own root-cause claims:
"Staging and Production share the same VPS and the same `.env` file" and
resolves by setting the live `hbec` role's password to **production's**
value from `/opt/hbec/.env`.

That claim is wrong: `docs/DEPLOYMENT.md` and this repo's own project
documentation are explicit that staging (`/home/winstontino/HBEC/.env.staging`)
and production (`/opt/hbec/.env`) are separate files on the same host,
precisely so a staging change can never touch production. That earlier
fix set the live role to a password that doesn't match staging's own
`.env.staging`/`docker/secrets/pg_password.txt` — which is exactly what
broke it again for this deploy.

### 3. Key Findings
- `postgres-staging`'s data volume was created **2026-08-01**;
  `docker/secrets/pg_password.txt` was last rotated **2026-08-03** —
  identical timeline to the 2026-09-09 incident, confirming Postgres never
  re-applies `POSTGRES_PASSWORD_FILE` after first `initdb`. That original
  drift was correctly fixed via `ALTER ROLE` on 2026-09-09 and held for two
  weeks; today's recurrence was a **fresh** drift introduced by an
  intervening, incorrect fix attempt earlier the same day, not a re-surfacing
  of the original gap.
- Running the deploy's own health checks alone would never have caught
  this — `docker compose up` only reports a container unhealthy, not
  *why*; the actual cause required the same manual `docker exec` +
  network-path auth test both prior incidents also needed.
- The guardrail proposed after the *second* occurrence
  (`HBEC-2026-09-16-runtime-secret-drift-had-no-detection-mechanism.md`,
  `scripts/check_runtime_secret_drift.py`) was real and already running —
  but its registry (`scripts/runtime_secrets.py`) only ever compared two
  *application* processes holding a copy of the same secret against each
  other. It had no way to represent "does this config's password actually
  authenticate against the database" at all — a structurally different
  check (an authentication attempt, not a value comparison), so this
  specific failure class was invisible to it by construction, the same way
  the two failures that *motivated* building it were invisible to the
  purely-static `check_config_parity.py` before it.

## Root Cause
Two layered causes:
1. **Structural (unchanged since 2026-09-09):** Postgres never re-applies
   `POSTGRES_PASSWORD_FILE` after first `initdb`, so a data volume's live
   role password can silently diverge from every application config
   pointing at it, invisibly, until something restarts a dependent
   container.
2. **Immediate (new today):** An earlier same-day fix attempt, based on a
   mistaken belief that staging and production share one `.env` file, set
   the live `hbec` role to production's password instead of staging's own —
   reintroducing the exact drift class the 2026-09-09 fix had already
   closed, hours later.

## Prevention / Rule
**Guardrail:** `scripts/runtime_secrets.py` gains a fourth check kind,
`"db_auth"`, alongside the existing `"env"`/`"file"` kinds — the first that
answers "does this config's password actually authenticate against the
live database" rather than "do two application processes agree", since for
this bug class there is no second application process to compare against,
only the database itself. Registered for both databases this exact failure
has now hit: main `postgres` (`hbec` role) and `harness-db` (`harness`
role). Connects to the database's own registered Compose service hostname,
never loopback, for the same reason the manual diagnosis always has to —
`pg_hba.conf` trusts loopback unconditionally in every environment here.

This closes the gap for real this time: run
`python3 scripts/check_runtime_secret_drift.py --compose-file
docker-compose.staging.yml --env-file .env.staging` as the last step of
any staging deploy or manual credential fix, and a wrong `ALTER ROLE`
target (like today's) fails the check immediately instead of waiting for
the next unrelated deploy to restart the affected containers and surface
it as a live crash loop.

## Solution

### Immediate Fix
```bash
docker exec hbec-postgres-staging psql -U hbec -d hbec_litellm \
  -c "ALTER ROLE hbec WITH PASSWORD '$(cat docker/secrets/pg_password.txt)';"
docker restart hbec-main-pgbouncer-staging hbec-litellm-staging
```
Verified over the real network path (not loopback) before and after;
`student-backend-staging`, `admin-backend-staging`, `main-pgbouncer-staging`,
`litellm-staging` all confirmed healthy afterward with no errors in their
logs.

### Long-term Fix
`scripts/runtime_secrets.py` / `scripts/check_runtime_secret_drift.py`
extended with `kind: "db_auth"` (see Prevention/Rule) — 8 new unit tests in
`scripts/tests/test_check_runtime_secret_drift.py`, covering: a correct
password passes, an incorrect one is flagged, a *different* Postgres FATAL
error (e.g. wrong database name) is deliberately **not** flagged as
credential drift (the first version of this check did false-positive on
that — caught by testing the negative case, not just the happy path),
either side not running is treated as not-applicable rather than an error,
and the password itself is never present in any reported error string.

## Verification
- Direct `_db_auth_check()` calls against live staging for both new
  groups: both `OK`.
- Deliberately wrong password against the real staging database: correctly
  flagged, with an actionable `ALTER ROLE` remediation message.
- Deliberately wrong `db_name` (a config mistake, not credential drift):
  correctly *not* flagged — this was a real bug in the first draft of the
  check (matching on any `FATAL`, not specifically `authentication
  failed`), caught before commit by testing the negative case.
- Full guardrail run against live staging: 2/2 new `db_auth` groups pass;
  the 7 pre-existing `env`/`file` groups it already covered still correctly
  report their (separate, pre-existing, not fixed in this pass — see
  Related Issues) drift.

## Prevention
- [x] Configuration changes needed — n/a (live role fixed directly, see
  Immediate Fix)
- [x] Monitoring/alerts to add — done, see Prevention/Rule
- [x] Documentation to update — this entry
- [x] Code changes required — done (`scripts/runtime_secrets.py`,
  `scripts/check_runtime_secret_drift.py`)

## Related Issues
- `Database_and_State/HBEC-2026-09-09-staging-postgres-secret-drift-crash-loop.md`
  — 1st occurrence, original diagnosis and fix pattern this one reused.
- `DevOps_and_Infrastructure/HBEC-2026-09-20-staging-postgres-password-drift.md`
  — 2nd occurrence.
- `Database_and_State/HBEC-2026-09-23-staging-postgres-password-drift.md`
  — 3rd occurrence, same day, whose own fix is the immediate cause of this
  4th one (see Root Cause).
- `DevOps_and_Infrastructure/HBEC-2026-09-16-runtime-secret-drift-had-no-detection-mechanism.md`
  — the guardrail this entry extends; its registry never covered database
  credentials, only application-to-application secrets.
- Running the extended guardrail against staging surfaced a **separate,
  pre-existing** drift across 7 secret groups (every `-beat` Celery beat
  container disagreeing with its corresponding main service) — not caused
  by or fixed in this pass, logged separately:
  `HBEC-2026-09-23-staging-beat-workers-holding-stale-secrets.md`.

## References
- `scripts/runtime_secrets.py`, `scripts/check_runtime_secret_drift.py`
- `scripts/tests/test_check_runtime_secret_drift.py`
- `docker/secrets/pg_password.txt`, `.env.staging` (both hand-maintained,
  never touched by CI/CD)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** ~40 minutes (live fix + guardrail extension, same
session)
