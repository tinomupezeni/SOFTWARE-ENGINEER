# SWAP-O-SELL — Database Design Decisions

**Last updated:** 2026-11-26

## Isolated PostgreSQL 16 for production, replacing a silent SQLite fallback — 2026-10-15
**Chose:** A dedicated `postgres:16-alpine` Compose service, private
`swaposell-internal` network (no host port, not shared with other VPS
tenants), required (not optional/fallback) `DATABASE_URL`,
`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` in production.
**Alternatives considered:** Continuing on SQLite in production (this was
the status quo only because `DATABASE_URL` was accidentally empty, not a
deliberate choice); sharing an existing VPS tenant's PostgreSQL instance
(rejected — isolation/credential separation from other tenants).
**Why:** Needed real concurrent-write marketplace persistence; a silent
SQLite fallback is fragile and was undetected (zero production records
existed when this was caught, so no data migration was needed — lucky,
not planned).
**Still valid?** Yes. Follow-up not yet done: scheduled `pg_dump` backups
and a restore drill.

## Local dev defaults to SQLite via `dj-database-url`, with a known gap — 2026-10-15 / 2026-11-04
**Chose:** `DATABASE_URL` unset → SQLite locally, for fast/dependency-light
local dev.
**Why:** Avoids requiring a local Postgres install for casual dev work.
**Still valid?** Partially — `django.contrib.postgres` is listed
unconditionally in `INSTALLED_APPS`, which pulls in a `psycopg2` import
even when SQLite is in use, breaking a bare non-Docker local run on a
fresh machine. See [[sqlite-dev-postgres-driver]] in `implementation/` —
not yet fixed at the `INSTALLED_APPS` level, workaround applied instead.
