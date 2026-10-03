# Incident: Staging Postgres Password Drift

## Issue
After updating the staging environment and manually rebuilding containers, the `hbec-admin-backend-staging` container crashed, returning 502 Bad Gateway errors. The postgres logs showed `FATAL: password authentication failed for user "hbec"`. 

## Root Cause
When the staging environment was updated, `hbec-postgres-staging` and `hbec-main-pgbouncer-staging` were recreated by Docker Compose because of changes pulled from git into `docker-compose.staging.yml`. 

The `hbec-postgres-staging` container's data volume was created a long time ago and was initialized using `/run/secrets/pg_password` (which contained the value `postgres_password_2024`). However, the `docker-compose.staging.yml` file configures all the staging applications (and `main-pgbouncer`) to use `${POSTGRES_PASSWORD}` from the host's `/opt/hbec/.env` file. Because Staging and Production share the same VPS and the same `.env` file, this variable contained the production password (`7Kx...`). 

When pgbouncer restarted, it generated its `userlist.txt` using the production password from `.env`. It then tried to authenticate against the staging postgres container using the production password, but the staging database still held the original `postgres_password_2024` in its persistent volume. The database rejected the connection, which bubbled up and crashed the application containers.

## Resolution
Manually accessed the `hbec-postgres-staging` container and executed an `ALTER ROLE hbec WITH PASSWORD '...';` command to update the staging database password to match the production password stored in `/opt/hbec/.env`. Once the passwords matched, the containers were restarted and the applications successfully connected to the database.

**Resolved By:** Antigravity
