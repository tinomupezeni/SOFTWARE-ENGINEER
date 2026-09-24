# sudo -E Preserving Shell Environment Overriding Docker Compose .env

**Date:** 2026-09-24
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
The admin backend container started failing with `500 Internal Server Error`s specifically on the login endpoint due to a database authentication failure (`FATAL: SASL authentication failed`). The root cause was executing `sudo -E docker compose up -d`, which preserved a stray `POSTGRES_PASSWORD` environment variable from the user's host shell. This shell variable silently overrode the correct password defined in the `.env` file, injecting an invalid password into the container at runtime.

## Symptoms
- The admin dashboard login endpoint returned `500 Internal Server Error`.
- The `hbec-admin-backend-staging` container logs showed `psycopg.OperationalError: connection failed: ... FATAL:  SASL authentication failed`.
- Inspecting the environment of the running container (`docker exec hbec-admin-backend-staging env`) revealed `POSTGRES_PASSWORD=8cac513d...`, which did not match the `7Kx...` password explicitly defined in the `.env` file.

## Environment Details
- **Server/Host:** VPS (hbca-vps)
- **Services Affected:** `hbec-admin-backend-staging`
- **Related Components:** Docker Compose, Host Shell Environment
- **Time First Observed:** 2026-09-24, immediately following a manual container recreation.

## Investigation Steps

### 1. Initial Diagnosis
- Verified that the previous database mismatch issue had been resolved and that `psycopg` scripts could connect successfully from within the container when provided the correct password.
- Pulled the runtime environment variables of the failing Django container and saw it was inexplicably using an old/incorrect password hash (`8cac...`).

### 2. Root Cause Analysis
- Checked `docker-compose.staging.yml` which expects `${POSTGRES_PASSWORD}` from `.env`.
- Checked `.env` and confirmed the correct password was written there.
- Checked the command history and observed the deployment command used: `sudo -E docker compose -f docker-compose.staging.yml ... up -d`.
- Realized the `-E` flag tells `sudo` to preserve the user's existing environment variables. Because the user's shell happened to have `POSTGRES_PASSWORD` exported, Docker Compose prioritized the host environment variable over the `.env` file.

### 3. Key Findings
- Docker Compose natively prioritizes shell environment variables over `.env` files.
- Using `sudo -E` for deployment scripts is dangerous because any stray variables in the operator's shell will silently inject themselves into the production/staging container environments, overriding tracked configurations.

## Root Cause
The deployment command used `sudo -E`, which preserved the host shell's environment variables. The host shell contained an exported `POSTGRES_PASSWORD` variable. Docker Compose read this variable from the shell and prioritized it over the `.env` file, injecting the wrong password into the `admin-backend` container upon recreation.

## Prevention / Rule
**Guardrail:** Never use `sudo -E` when running `docker compose` deployment commands. Always run `sudo docker compose ...` so that the execution environment is clean and forces Compose to strictly rely on the project's `.env` files rather than the unpredictable state of the operator's shell.

This guarantees that the container environment exactly matches the documented configuration files, preventing silent overrides and drift.

## Solution

### Immediate Fix
Restarted the affected containers without the `-E` flag to ensure they pull strictly from `.env`:

```bash
sudo docker compose -f docker-compose.staging.yml --profile workers up -d admin-backend student-backend
```

### Long-term Fix
Ensure all deployment documentation and scripts omit the `-E` flag when invoking Docker Compose via `sudo`.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update: Update any manual deployment runbooks to explicitly forbid `sudo -E` for docker compose.
- [ ] Code changes required

## Related Issues
- N/A

## References
- Docker Compose Environment Variable Precedence.

---

**Resolved By:** Antigravity
**Time to Resolution:** ~10 minutes
