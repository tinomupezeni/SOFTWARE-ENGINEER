# Staging Langfuse Is Restart-Looping on a Postgres Auth Failure

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging
**Severity:** Low
**Status:** Resolved

## Summary
Noticed while doing an unrelated final health sweep after promoting
today's work to production: `hbec-langfuse-staging` is stuck in a restart
loop, failing its own Prisma migration step against `langfuse-db` with a
Postgres authentication error. Not caused by anything touched this
session — no langfuse-related files, env vars, or containers were part of
today's work.

## Symptoms
```
Error: P1000: Authentication failed against database server at
`langfuse-db`, the provided database credentials for `langfuse` are not
valid.
Applying database migrations failed. This is mostly caused by the
database being unavailable.
Exiting...
```
Container status: `Restarting (1)`, looping continuously.

## Environment Details
- **Server/Host:** hbca-vps, staging (`/home/winstontino/HBEC`)
- **Services Affected:** `hbec-langfuse-staging` only (LLM observability/
  tracing tool, not user-facing)
- **Time First Observed:** 2026-09-14, during an unrelated post-deploy
  health check

## Investigation Steps

### 1. Initial Diagnosis
```bash
docker ps -a --filter 'status=restarting'
# hbec-langfuse-staging: Restarting (1)
docker logs hbec-langfuse-staging --tail 20
# Error: P1000: Authentication failed against database server at
# `langfuse-db`
```

### 2. Root Cause Analysis
Both `langfuse` and `langfuse-db` reference the identical env var
(`LANGFUSE_DB_PASSWORD`, defaulting to `langfuse_db_pass`) for the
Postgres password — `docker-compose.staging.yml:994` for `langfuse-db`'s
`POSTGRES_PASSWORD`, `:1020` for `langfuse`'s `DATABASE_URL`. Since both
read the same source, they should never disagree — unless the Postgres
volume was already initialized under an *older* value before
`.env.staging`'s `LANGFUSE_DB_PASSWORD` (currently `langfuse_dev_password`)
was set to its current value. `POSTGRES_PASSWORD` only takes effect on
first initialization of an empty data directory; changing it afterward
has no effect on the already-created role's actual password. Confirmed by
testing: local trust-auth inside `langfuse-db-staging` succeeded
regardless of password (expected — local socket connections bypass
password auth under Postgres's default `pg_hba.conf`), but a real TCP
connection to `langfuse-db:5432` — the same path the `langfuse` container
actually uses — failed with `password authentication failed for user
"langfuse"` using the current `.env.staging` value, proving the stored
role password had drifted from the current config.

## Root Cause
`langfuse-db-staging`'s Postgres data volume was initialized at some
earlier point under a different `LANGFUSE_DB_PASSWORD` value than what
`.env.staging` currently holds. The env var itself was presumably changed
at some point (a rotation, or a value entered differently the first vs. a
later time) without anyone re-applying it to the already-initialized
database role — `POSTGRES_PASSWORD` is init-only, not enforced on every
container start.

## Prevention / Rule
**Guardrail:** For any Postgres-backed service reusing a persistent
volume, changing the corresponding `*_PASSWORD` env var must be paired
with an explicit `ALTER USER ... WITH PASSWORD ...` against the live
database — a plain env var or secrets-file update is silently a no-op
once the volume already exists. Worth a one-line note in the deploy
runbook next to any `POSTGRES_PASSWORD`-style variable making this
explicit, since it's a well-known but easy-to-forget Postgres container
behavior.

This closes the gap because the actual failure mode isn't "wrong
password chosen" — it's "the right password was set somewhere that
doesn't automatically propagate to an already-initialized volume," which
only a documented pairing (env change + `ALTER USER`) reliably prevents.

## Solution

### Immediate Fix
```bash
docker exec hbec-langfuse-db-staging psql -U langfuse -d langfuse_db \
  -c "ALTER USER langfuse WITH PASSWORD 'langfuse_dev_password';"
docker restart hbec-langfuse-staging
```
Verified: a real TCP connection to `langfuse-db:5432` with the current
`.env.staging` password now succeeds, and `hbec-langfuse-staging` came up
healthy (`271 migrations found... No pending migrations to apply`, `Ready
in 9.3s`) with no further restarts.

### Long-term Fix
None needed beyond the guardrail above — the credential is now
reconciled and matches `.env.staging` going forward until the next time
someone changes `LANGFUSE_DB_PASSWORD` without also updating the live
role.

## Prevention
- [x] Configuration changes needed — done (role password reconciled)
- [ ] Monitoring/alerts to add — a restart-loop alert (e.g. `ServiceDown`
      already exists in principle via `up==0`, but a Prisma-migration
      crash-loop before the app ever binds its port may not trip a scrape
      failure the same way — worth checking whether `up{job=~"langfuse"}`
      is actually scraped at all)
- [ ] Documentation to update — the deploy runbook note described above
- [x] Code changes required — none; this was a data-plane fix, not code

## Related Issues
- None yet — first time noticed.

## References
- `docker-compose.staging.yml` — `langfuse`, `langfuse-db` services

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery
