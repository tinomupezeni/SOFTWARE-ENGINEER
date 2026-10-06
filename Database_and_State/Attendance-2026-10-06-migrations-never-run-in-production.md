# Production Database Had Zero Tables: Alembic Migrations Were Never Wired Into the Deployment (and Had Two Latent Bugs of Their Own)

**Date:** 2026-10-06
**Project:** Attendance
**Environment:** Production (smepulse-vm, first deployment)
**Severity:** Critical
**Status:** Resolved

## Summary
While fixing the admin router (see `Attendance-2026-10-06-admin-router-never-registered-and-schema-drift.md`), every database-backed endpoint failed with `relation "employees" does not exist`. The production Postgres volume had been running for over an hour (healthy, accepting connections, `/health/ready` reporting `database: connected`) but held zero application tables — because nothing in the deployment ever ran Alembic migrations. Attempting to run them by hand then surfaced that Alembic wasn't even an installed dependency of the project, and that the one existing migration environment (`migrations/env.py`) had two further bugs that would have broken it even once installed.

## Symptoms
- `/admin/employees`, `/admin/ledger`, `/admin/workplaces`, `/admin/devices` all returned HTTP 500 with `sqlalchemy.exc.ProgrammingError: relation "employees" does not exist`.
- `docker exec attendance-db-1 psql -U attendance_user -d attendance -c '\dt'` showed only PostGIS/TIGER system tables — no `employees`, `workplaces`, `attendance_events`, etc.
- `/health/ready` reported `{"status":"ready","database":"connected"}` the entire time — a healthy TCP/auth connection to Postgres is not the same as a usable schema, and the shallow check didn't distinguish them.

## Environment Details
- **Server/Host:** smepulse-vm, containers `attendance-db-1` / `attendance-backend-1`
- **Services Affected:** Every database-backed endpoint on the backend
- **Related Components:** `backend/pyproject.toml`, `backend/migrations/env.py`, `backend/Dockerfile.production`
- **Time First Observed:** 2026-10-06, while debugging the admin router fix above

## Investigation Steps

### 1. Initial Diagnosis
Every write/read against a real table failed identically regardless of which admin.py bug had just been fixed, pointing away from application code and at the schema itself. `\dt` confirmed the tables simply didn't exist.

### 2. Root Cause Analysis — Layer 1 (never installed)
```bash
grep -n "alembic" pyproject.toml   # -> no output; not a declared dependency at all
```
Nothing in `Dockerfile`/`Dockerfile.production` ever ran `alembic upgrade head`, and `alembic` wasn't even importable in the built image — the migration tooling existed as files (`alembic.ini`, `migrations/env.py`, one versioned migration) but had literally never been executed against this or, likely, any environment.

### 3. Root Cause Analysis — Layer 2 (broken even once installed)
After adding `alembic` to `pyproject.toml` and running it, it failed immediately:
```
sqlalchemy.exc.NoSuchModuleError: Can't load plugin: sqlalchemy.dialects:postgresql.asyncpg://attendance_user:...@db:5432/attendance
```
`migrations/env.py`'s `run_migrations_online()` did `configuration = URL.create(url)` where `url` was the *entire connection string as one string* — but `sqlalchemy.engine.URL.create()` expects the URL's individual components (`drivername=`, `username=`, etc.) as separate keyword arguments, not a single string. Passing the whole string positionally made SQLAlchemy treat it as the `drivername` value, so it tried (and failed) to look up a dialect literally named `postgresql+asyncpg://attendance_user:...`.

Separately, `env.py`'s own `get_sqlalchemy_url()` built its connection string from `DATABASE_USER`/`DATABASE_PASSWORD`/`DATABASE_HOST`/`DATABASE_PORT`/`DATABASE_NAME` env vars — a completely different naming scheme from the single `DATABASE_URL` env var the application itself (`app/database.py`) and the deployment's `docker-compose.production.yml` actually use. Even with the `URL.create` bug fixed, this would have defaulted to `db_host="localhost"` inside the container and connected to nothing.

## Root Cause
Alembic was scaffolded (config file, env.py, one migration) at some point but never actually integrated into any deployment path or declared as a project dependency, and the scaffolding itself had never been run even once, so it carried two independent bugs (a URL-construction bug and an env-var-naming mismatch) that only surfaced the first time anyone tried to actually use it.

## Prevention / Rule
**Guardrail:** This is the SDLC guide's "Potemkin tooling" pattern again, applied to migrations specifically: a migration tool that has never been run against a database is unverified by definition, regardless of how complete the files look. The closing guardrail is a CI job that spins up a throwaway Postgres container and runs `alembic upgrade head` against it on every PR — not just linting the migration files, but actually executing them — so a broken or disconnected migration path fails CI instead of surfacing for the first time during a real deployment.

## Solution

### Immediate Fix
- Added `alembic>=1.13.0` to `backend/pyproject.toml` dependencies.
- Fixed `migrations/env.py`: `get_sqlalchemy_url()` now prefers the `DATABASE_URL` env var (matching `app/database.py` and the compose file) before falling back to the individual-var composition; `run_migrations_online()` now passes the URL string directly to `create_async_engine()` instead of mis-using `URL.create()`.
- Added `backend/docker-entrypoint.production.sh` (`alembic upgrade head` then `exec "$@"`) and wired it as the `Dockerfile.production`'s `ENTRYPOINT`, so migrations run automatically on every container start rather than requiring a manual step.
- Rebuilt and redeployed; confirmed all 8 application tables plus `alembic_version` now exist, and every previously-failing endpoint now succeeds end-to-end (verified with real writes: employee creation, workplace creation + update, device pairing-token + pair, per the admin-router bug log above).

### Long-term Fix
Add the CI migration-execution gate described above.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `Attendance-2026-10-06-admin-router-never-registered-and-schema-drift.md` — found in the same investigation; that bug's write-path fixes couldn't be verified until this one was also resolved.

## References
- `Principal_Engineer/engineering-guides/1. SDLC.md` ("Potemkin tooling" pattern)
- `Principal_Engineer/engineering-guides/6. Database Engineering.md`

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** ~30 minutes
