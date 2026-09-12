# Staging Postgres/Pgbouncer Password Drift — Restarting Long-Lived Containers Exposed a Silent Credential Mismatch

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved (student/admin path); one instance (Langfuse) still broken, out of scope

## Summary
While deploying three unrelated bug fixes to staging (an auth fallback fix, an exam-board data validation fix, and an Ollama GPU-fallback config fix), restarting `main-pgbouncer-staging`, `student-backend-staging`, and `admin-backend-staging` put them into an immediate crash loop: `FATAL: password authentication failed for user "hbec"`. The same class of failure then hit `harness-staging` via its own pgbouncer. Neither service's *code* had anything to do with database credentials — the deploy just happened to be the first thing to restart these containers in a long time, and restarting them read a `.env.staging` password that had silently stopped matching reality.

## Symptoms
- `student-backend-staging` and `admin-backend-staging`: `django.db.utils.OperationalError: connection failed: connection to server at "172.25.0.14", port 5432 failed: FATAL: password authentication failed for user "hbec"`, crash-looping.
- `harness-staging`: hung indefinitely at `==> Waiting for database...`, never crashing, never becoming healthy.
- `hbec-pgbouncer-staging` (harness's own bouncer) logs: `password authentication failed for user "harness"`, repeating on every connection attempt.
- `hbec-payments-staging`: `asyncpg.exceptions.ProtocolViolationError: SASL authentication failed`, crash-looping — same `hbec`/`main-pgbouncer` credential, different database (`hbec_payments`). Surfaced downstream as `GET /api/subscription/` returning **502 Bad Gateway** on the student frontend ("Payment service unavailable").
- `hbec-schools-backend-staging`: `django.db.utils.OperationalError ... FATAL: SASL authentication failed` against `main-pgbouncer` — same root cause, third service on the same shared `hbec` credential.
- `hbec-langfuse-staging`: separately restart-looping with `Error: P1000: Authentication failed against database server at langfuse-db` — same failure signature, different service, not fixed in this pass.

## Environment Details
- **Server/Host:** `hbca-vps`, staging environment only (`/home/winstontino/HBEC`) — production (`/opt/hbec`) was deliberately not touched
- **Services Affected:** `hbec-main-pgbouncer-staging`, `hbec-postgres-staging` (config only, not the DB itself), `hbec-pgbouncer-staging`, `hbec-harness-db-staging`, `hbec-student-backend-staging`, `hbec-admin-backend-staging`, `hbec-harness-staging`, `hbec-payments-staging`, `hbec-schools-backend-staging`; `hbec-langfuse-staging` affected but unresolved
- **Related Components:** `.env.staging` (hand-maintained, never touched by `cd.yml`), `docker/secrets/*.txt` (hand-maintained secret files), `docker-compose.staging.yml`'s `secrets:` block
- **Time First Observed:** 2026-09-09, immediately after restarting containers that had been running 45+ hours without interruption

## Investigation Steps

### 1. Initial Diagnosis
`docker logs hbec-student-backend-staging` showed the auth failure immediately after restart. Confirmed it wasn't caused by the code being deployed (nothing in the three target commits touches database configuration).

### 2. Root Cause Analysis
Checked what password each side actually had:
```bash
grep POSTGRES_PASSWORD ~/HBEC/.env.staging
# POSTGRES_PASSWORD=hbec_dev_password

docker exec hbec-postgres-staging printenv | grep POSTGRES
# POSTGRES_PASSWORD_FILE=/run/secrets/pg_password   (NOT the plain env var)

cat ~/HBEC/docker/secrets/pg_password.txt
# 8cac513d...  (redacted here — long generated value, doesn't match .env.staging)
```
`docker-compose.staging.yml`'s `secrets:` block confirmed `pg_password` maps to `./docker/secrets/pg_password.txt` — a long, clearly-generated value, root-owned, dated **2026-08-03**. `.env.staging`'s plain `POSTGRES_PASSWORD` is a generic placeholder (`hbec_dev_password`) that has never matched it.

Fixed `.env.staging` to the real secret and recreated `main-pgbouncer-staging` + the two backend services — they came up healthy. The exact same pattern then surfaced for `harness-db`: `.env.staging`'s `HARNESS_DB_PASSWORD=harness_dev_password` didn't match `docker/secrets/harness_db_password.txt` (`500fcdda9...`). Fixed the same way — but this time, even after both `pgbouncer-staging` and `harness-staging` had the corrected value, the connection still failed.

The deeper problem: my first "successful" verification (`psql -h localhost ...`) was a false positive — `pg_hba.conf` inside `harness-db-staging` grants `trust` (no password check at all) for `127.0.0.1`, but requires `scram-sha-256` for every other host, which is what pgbouncer actually uses. Testing over the real container network reproduced the failure. Comparing timestamps explained why:
```bash
docker exec hbec-harness-db-staging stat -c "%y" /var/lib/postgresql/data/PG_VERSION
# 2026-08-01 10:19:44   <- database initialized here, password baked in from
#                          whatever the secret file held AT THAT TIME
stat docker/secrets/harness_db_password.txt
# 2026-08-03 12:01:34   <- secret file content changed TWO DAYS LATER
```
Postgres only applies `POSTGRES_PASSWORD_FILE` at first `initdb` — never on restart. The secret file was rotated on 2026-08-03, but the already-initialized data volume kept whatever password it was born with two days earlier. That earlier value isn't recoverable from anywhere in the repo or secrets directory — it only ever existed inside the database itself. Fixed by connecting via the trusted local socket (the one path `pg_hba.conf` allows without a password) and issuing `ALTER ROLE harness WITH PASSWORD '<current secret file value>'` directly, bringing the live role in line with what the secret file — and now `.env.staging` — actually say.

### 3. Key Findings
- **`.env.staging`'s placeholder passwords (`*_dev_password`) had silently diverged from the real secrets in `docker/secrets/*.txt` for at least five weeks**, invisibly, because the affected containers simply hadn't been restarted in that time. Long uptime was hiding the drift, not proving correctness.
- Fixing the *config* (`.env.staging`) is not always sufficient — if a Postgres data volume was already initialized under an older value, the live role's password is independent of both the config and the secret file after that point, and requires a direct `ALTER ROLE` (or a full volume reset, which is far more destructive) to reconcile.
- A "successful" password test via `localhost`/`127.0.0.1` proves nothing on a host whose `pg_hba.conf` trusts loopback unconditionally — the only valid test is over the same network path the real client actually uses.
- Confirmed at least three instances of the identical pattern (`hbec`/main postgres, `harness`/harness-db, `langfuse`/langfuse-db — all named `*_dev_password` in `.env.staging`). Only the first two were fixed in this pass; Langfuse's is a different failure shape (its current env already matches `.env.staging`, so its root cause needs separate investigation) and was left broken, flagged for follow-up.
- Also noticed incidentally: `~/HBEC/staging.sh`, the hand-maintained management wrapper `docs/MANUAL_DEPLOY_PROMOTION.md` assumes exists, is **not present** on the VPS at all. Worked around by invoking `docker compose` directly with the same flags the runbook describes it using.
- Also noticed: an unused `docker/secrets/staging/harness_db_password.txt` exists with a **third**, different value — not referenced anywhere in `docker-compose.staging.yml`. Dead leftover, not cleaned up, worth removing so it doesn't get mistaken for the real one later.
- **Missed two more services on the first pass**: `payments-staging` and `schools-backend-staging` both also connect through `main-pgbouncer` using the same `hbec` credential (different database names — `hbec_payments`, presumably a schools-specific DB), and both had been recreated by an earlier full-stack `docker compose up` *before* the `.env.staging` fix landed, but weren't included in the follow-up targeted-service restart. Surfaced live: a user reported `GET /api/subscription/` returning 502 on the student frontend ("Payment service unavailable"). Fixed the same way (recreate to pick up the corrected env var); confirmed via a direct HTTP check that the endpoint now returns a proper `401` instead of a gateway failure. This is the practical lesson — after a shared-credential fix, every service sharing that credential needs checking, not just the ones that happened to crash first.

## Root Cause
`.env.staging` was never updated when the real secret files under `docker/secrets/` were generated (2026-08-03), leaving generic placeholder passwords in the env file that no longer matched the actual secrets docker-compose feeds into the database containers via `*_FILE` env vars. This was invisible for weeks because nothing restarted the affected containers. For `harness-db` specifically, the drift is deeper than a config mismatch: the database's own initialized password predates even the secret file's last rotation, so the live role password had to be fixed directly, not just the surrounding config.

## Prevention / Rule
**Guardrail:** A scheduled probe that connects to each database over the real service network path (not loopback, which `pg_hba.conf` can trust unconditionally) using the current `.env`/secret-file value, alerting on auth failure — plus a hard rule that rotating any file under `docker/secrets/` and updating the corresponding `.env`/`.env.staging` value must land in the same change, including an `ALTER ROLE` for any already-initialized database whose role predates the rotation.

This directly closes the gap that let the drift sit invisible for five weeks: nothing restarted the containers, so nothing ever tried the real credential until this deploy happened to.

## Solution

### Immediate Fix
- `.env.staging`: `POSTGRES_PASSWORD`/`POSTGRES_PASSWORD_ENCODED` and `HARNESS_DB_PASSWORD` updated to match their respective `docker/secrets/*.txt` files (backed up first: `.env.staging.bak-<timestamp>`).
- `harness-db-staging`'s `harness` role password reset directly via `ALTER ROLE` (through the trusted local socket) to match the now-correct secret value, since the data volume predated the secret file's last rotation.
- `main-pgbouncer-staging`, `pgbouncer-staging` (harness's bouncer), `student-backend-staging`, `admin-backend-staging`, `harness-staging`, `payments-staging`, `schools-backend-staging` recreated/restarted to pick up the corrected values. All confirmed healthy and functionally verified afterward (not just healthchecks — see References for the live 401/200/validation tests run against each fix).

### Long-term Fix
Not done in this pass — flagged for follow-up:
- Resolve `hbec-langfuse-staging`'s separate credential failure (same symptom, different root cause since its current env already matches `.env.staging`).
- Delete the unused, third-value `docker/secrets/staging/harness_db_password.txt` so it can't be mistaken for the real secret later.
- Restore or rewrite `staging.sh`, since `docs/MANUAL_DEPLOY_PROMOTION.md` depends on it existing.
- Audit `.env.staging` and `docker-compose.production.yml`'s equivalent secrets for the same drift risk on production — this pass deliberately never touched `/opt/hbec`, so production's own secret/env alignment is unverified.

## Prevention
- [ ] A startup-time check (or a scheduled one) that connects to each database over the real network path — not loopback — and alerts if auth fails, rather than relying on someone restarting a container to discover it
- [ ] When rotating a secret file under `docker/secrets/`, the accompanying `.env`/`.env.staging` value and any already-initialized database role must be updated in the same change, not just the file
- [ ] Documentation to update: `docs/MANUAL_DEPLOY_PROMOTION.md` should note that `staging.sh` may not actually be present and give the direct `docker compose` equivalent inline
- [ ] Remove the dead `docker/secrets/staging/` directory (or clarify what it's for, if anything)

## Related Issues
- Deployed alongside three unrelated fixes documented separately:
  [O-Level exam board validation](./2026-09-09-olevel-not-in-exam-board-supported-levels.md),
  [silent auth fallback](./2026-09-09-stale-guest-subjects-on-silent-auth-failure.md)
- [GitHub Actions billing-blocked manual deploy fallback](./2026-08-19-github-actions-billing-blocked-manual-deploy-fallback.md) — the automated staging deploy for these same commits stalled again, which is what led to doing this deploy by hand and surfacing this issue in the first place

## References
- `~/HBEC/.env.staging`, `~/HBEC/docker/secrets/pg_password.txt`, `~/HBEC/docker/secrets/harness_db_password.txt`
- `docker-compose.staging.yml` — `secrets:` block, `postgres`/`harness-db`/`pgbouncer`/`main-pgbouncer` service definitions
- Live verification after the fix (all against `*-staging`, none against production):
  - GPU fallback: `litellm-staging` reached the ZCHPC tunnel (`http://172.17.0.1:11436/api/tags`) → 200
  - Auth fix: `SubjectListView` with a bogus bearer token → 401 (previously would have silently served guest data); with no token at all → still 200 (guest path intact)
  - Exam-board validation: `ExamBoardCreateSerializer` rejects `gradeLevels: ["lower_secondary"]`, accepts `["o_level", "a_level"]`
  - Payments: `GET https://staging-student.hbca.tech/api/subscription/` went from `502 Bad Gateway` to `401` (proper auth-required response) once `payments-staging` was recreated

---

**Resolved By:** Claude Code (Sonnet 5)
**Time to Resolution:** ~45 minutes (discovered mid-deploy, staging only)
