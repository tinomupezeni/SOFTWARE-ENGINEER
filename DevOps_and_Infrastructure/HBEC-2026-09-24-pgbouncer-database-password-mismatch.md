# PgBouncer and Postgres Password Mismatch Causing 500 Errors

**Date:** 2026-09-24
**Project:** HBEC
**Environment:** Staging
**Severity:** Critical
**Status:** Resolved

## Summary
The admin dashboard was throwing `500 Internal Server Error`s for multiple endpoints (`/api/replication/stats/`, `/api/settings/system-errors/`) due to database connection failures. The root cause was a mismatch between the database passwords in the `.env` file and the actual passwords inside the existing `postgres` and `harness-db` containers, which surfaced when PgBouncer containers were recreated and attempted to connect using the new `.env` passwords.

## Symptoms
- The admin dashboard displayed 500 Internal Server Errors for API endpoints fetching from the backend.
- The `hbec-admin-backend-staging` container logs showed `psycopg.OperationalError: connection failed: connection to server at "172.25.0.16", port 5432 failed: FATAL:  SASL authentication failed` (and later `FATAL: password authentication failed`).
- The `hbec-main-pgbouncer-staging` and `hbec-pgbouncer-staging` logs showed `server login failed: FATAL password authentication failed for user "hbec"` and `server login failed: FATAL password authentication failed for user "harness"`.

## Environment Details
- **Server/Host:** VPS (hbca-vps)
- **Services Affected:** `main-pgbouncer-staging`, `pgbouncer-staging`, `admin-backend-staging`, `student-backend-staging`, `harness-staging`
- **Related Components:** `postgres-staging`, `harness-db-staging`
- **Time First Observed:** 2026-09-24, after recreating containers for a deployment.

## Investigation Steps

### 1. Initial Diagnosis
- Noticed the frontend errors and checked the `admin-backend` logs.
- Discovered `psycopg.OperationalError` indicating SASL authentication failures when trying to connect to `main-pgbouncer`.

### 2. Root Cause Analysis
- Searched `pgbouncer` container logs and saw it was failing to log into the upstream `postgres` server: `password authentication failed`.
- Checked `docker-compose.staging.yml` and saw PgBouncer uses `DATABASE_URL` with the password sourced from `.env` (`POSTGRES_PASSWORD` and `HARNESS_DB_PASSWORD`).
- Verified that the `.env` file contained updated passwords, but the Postgres initialization secret files (`pg_password.txt`, `harness_db_password.txt`) contained the older passwords.
- Realized that because the database volumes persist, Postgres was still using the original passwords, while PgBouncer (which was recreated due to a compose file update) was now using the new passwords from `.env`.

### 3. Key Findings
- PgBouncer with `AUTH_TYPE: md5` or `scram-sha-256` will generate `userlist.txt` based on the `DATABASE_URL` in its environment.
- If the `.env` password is changed after database initialization, applications will fail to connect if they use the new password while the database still holds the old one.
- PgBouncer dropping the server connection causes the client connections to immediately fail with SASL or password auth errors.

## Root Cause
When the `.env` passwords were updated in the repository or server recently, the actual Postgres user passwords inside the persistent volumes were not updated to match. Once the PgBouncer containers were recreated during a routine deployment, they fetched the new passwords from `.env`, resulting in authentication failure against the Postgres databases holding the old passwords.

## Prevention / Rule
**Guardrail:** When updating database credentials in `.env`, always run a script or explicit `ALTER ROLE <user> WITH PASSWORD '<new_password>';` command against the running database to ensure the internal state matches the environment variables, or ensure database initialization scripts force password synchronization on startup.

This prevents the desynchronization of credentials between application containers (which read `.env` freshly on recreate) and stateful database containers (which only read passwords on initial volume creation).

## Solution

### Immediate Fix
Manually accessed both the `postgres` and `harness-db` containers via `docker exec` and updated the passwords using `ALTER ROLE` to match the current `.env` variables.

```bash
# Fix for hbec-postgres-staging
docker exec hbec-postgres-staging psql -U hbec -d postgres -c "ALTER ROLE hbec WITH PASSWORD '7KxQmNp9vWzRjL3tYhF8cB2nD5sG4wE6';"

# Fix for hbec-harness-db-staging
docker exec hbec-harness-db-staging psql -U harness -d harness_db -c "ALTER ROLE harness WITH PASSWORD '9mTqX2nL8pV4rW7zC3kH6yJ5bN1sD0fG';"
```

### Long-term Fix
Synchronize the secrets across all `.env` files and `secrets.txt` files so that if the database is ever wiped, it will initialize with the correct credentials.

## Prevention
- [ ] Configuration changes needed: Ensure `pg_password.txt` and `harness_db_password.txt` match `.env`.
- [ ] Monitoring/alerts to add
- [ ] Documentation to update: Add a note about manually altering Postgres roles when changing `.env` passwords.
- [ ] Code changes required

## Related Issues
- N/A

## References
- Docker Compose volume persistence documentation.
- edoburu/pgbouncer documentation on `DATABASE_URL` and `AUTH_TYPE`.

---

**Resolved By:** Antigravity
**Time to Resolution:** ~30 minutes
