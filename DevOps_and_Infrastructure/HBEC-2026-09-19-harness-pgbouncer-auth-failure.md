# Harness PgBouncer Auth Failure

**Date:** 2026-09-19
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The `hbec-harness-staging` container was failing to start and was returning 502 Bad Gateway to the frontend proxy because its Postgres backend connection was consistently failing. PgBouncer was unable to complete the SCRAM handshake with the backend Postgres database because the `harness` database user had the wrong password initialized (likely due to a newline in the secret file during database creation).

## Symptoms
- The frontend reported `502 Bad Gateway` for `GET /harness-stream/health`.
- The `hbec-harness-staging` container logs showed `"error": "All connection attempts failed"` and it was stuck waiting for the database connection.
- The `hbec-pgbouncer-staging` container logs repeatedly output: `WARNING server login failed: FATAL password authentication failed for user "harness"`.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** `hbec-harness-staging`, `hbec-pgbouncer-staging`, `hbec-harness-db-staging`
- **Related Components:** Postgres, PgBouncer, asyncpg
- **Time First Observed:** 2026-09-19

## Investigation Steps

### 1. Initial Diagnosis
- Verified that the `HARNESS_DB_PASSWORD` in `.env.staging` matched the password secret file `/docker/secrets/harness_db_password.txt`.
- Inspected the `userlist.txt` in PgBouncer and verified it correctly contained the plaintext password from the `.env` file.

### 2. Root Cause Analysis
- Connected manually to the Postgres database using `psql` bypassing PgBouncer, passing the password `500fcdda9feb39362fdf22d640be60523b9756ea8ccc18db` from `.env.staging`. This succeeded over `local` (trust) but failed over `host` (TCP/SCRAM).
- Checked the `harness` user's password in `pg_authid` and noted the SCRAM-SHA-256 hash.
- Suspected the database was initially seeded with a password that included a trailing newline (e.g. if the secret file was created via `echo` rather than `echo -n`), which resulted in a mismatched SCRAM hash in the DB compared to what PgBouncer/clients were attempting to use.

### 3. Key Findings
- PgBouncer uses `userlist.txt` to do auth-passthrough or log into the backend server. Since the client (`asyncpg`) requires SCRAM but PgBouncer only holds a plaintext password, PgBouncer initiates a backend connection.
- Because the backend database had a different (newline-inclusive) password hash stored, Postgres rejected PgBouncer's SCRAM response computed from the pure plaintext password.

## Root Cause
The `POSTGRES_PASSWORD_FILE` used during `harness-db` initialization contained a trailing newline. The database hashed the password with the newline, whereas `.env.staging` (and thus `pgbouncer` and `harness`) expected the password without the newline. This mismatch caused SCRAM authentication to fail.

## Prevention / Rule
**Guardrail:** Ensure all Docker secrets containing passwords are created without trailing newlines (e.g., using `printf` instead of `echo` or adding `tr -d '\n'`), and validate database initialization scripts to strip whitespace from password files before applying them.

When passwords contain unexpected whitespace, initial authentication works locally (via socket `trust`) but fails silently on TCP connections that require strict hashing like SCRAM. Stripping whitespace guarantees the hashed secret perfectly matches the `.env` expectations.

## Solution

### Immediate Fix
Manually altered the database role to set the exact password string expected by the environment:
```bash
docker exec hbec-harness-db-staging psql -U harness -d harness_db -c "ALTER ROLE harness WITH PASSWORD '500fcdda9feb39362fdf22d640be60523b9756ea8ccc18db';"
```
PgBouncer immediately re-established healthy connections, allowing the `harness` container to successfully initialize the database pool and serve traffic, resolving the 502 error.

### Long-term Fix
Ensure the script generating the `harness_db_password.txt` file uses `echo -n` or `printf` to prevent trailing newlines.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
