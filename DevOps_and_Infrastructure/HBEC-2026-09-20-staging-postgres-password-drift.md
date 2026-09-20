# Postgres Password Drift Causing Staging Crash

**Date:** 2026-09-20
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The staging environment crashed during a deployment because `hbec-litellm-staging` and `hbec-main-pgbouncer-staging` could not authenticate with the database. This was caused by configuration drift: the `POSTGRES_PASSWORD` in `.env.staging` had changed, but the password inside the persistent Postgres data volume (`postgres_data_staging`) had not been updated.

## Symptoms
- `hbec-litellm-staging` crash-looped on startup with `httpx.ConnectError: All connection attempts failed` while attempting to hit the Prisma engine.
- `hbec-main-pgbouncer-staging` logs showed `server login failed: FATAL password authentication failed for user "hbec"`.
- Production was unaffected.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** `hbec-litellm-staging`, `hbec-main-pgbouncer-staging`
- **Related Components:** `hbec-postgres-staging`, `.env.staging`
- **Time First Observed:** 2026-09-20 14:00

## Investigation Steps

### 1. Initial Diagnosis
The staging deployment showed `hbec-litellm-staging` as unhealthy. Checking its logs revealed it could not connect to its Prisma query engine, which in turn was panicking because it couldn't connect to `postgres:5432`.

### 2. Root Cause Analysis
Checked network connectivity between containers on `db-net`; all passed. Ran a manual connection test via `psql` from within the postgres container using the `.env.staging` connection string, which returned a password authentication failure. 
Further inspection revealed that while `.env.staging` and the docker secret `pg_password.txt` were correctly aligned, the persistent volume (`postgres_data_staging`) retained an older password from its initial setup.

```bash
# Commands used for investigation
docker exec hbec-postgres-staging psql postgres://hbec:8cac513d3ec3211999ddd1c1a77087358755e77a22463780@postgres:5432/hbec_litellm -c '\q'
```

### 3. Key Findings
- The `postgres` Docker image only consumes `POSTGRES_PASSWORD_FILE` (or `POSTGRES_PASSWORD`) on initial volume creation.
- Subsequent changes to the `.env` or secret files do not automatically update the password inside the database.

## Root Cause
A change to the `POSTGRES_PASSWORD` in `.env.staging` updated the application services (`pgbouncer`, `litellm`), but because the `hbec-postgres-staging` container uses a persistent volume, the database itself did not auto-update the user password on restart. This mismatch locked out all services attempting to connect via the new password.

## Prevention / Rule
**Guardrail:** We should implement a health check script in CI/CD or deploy pipelines that validates the `.env` credentials against the running database before deploying reliant services, or automate a password sync script if passwords are rotated.

A script that runs `psql -c "ALTER USER..."` automatically if a password rotation is detected in `.env` would prevent services from deploying into a guaranteed-failure state.

## Solution

### Immediate Fix
Manually reset the `hbec` user password inside the running Postgres container to match the `.env.staging` value.

```bash
docker exec hbec-postgres-staging psql -U hbec -c "ALTER USER hbec WITH PASSWORD '8cac513d3ec3211999ddd1c1a77087358755e77a22463780';"
docker compose -f docker-compose.staging.yml restart litellm
```

### Long-term Fix
Ensure any password rotation procedure includes steps to update the credentials inside the persistent database volumes, not just in `.env` files.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- The deployment was initially paused to fix a `ModuleNotFoundError` for `paper_bands.py`.

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 1 hour
