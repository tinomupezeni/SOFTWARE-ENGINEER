# Staging Langfuse Is Restart-Looping on a Postgres Auth Failure

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging
**Severity:** Low
**Status:** Investigating

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
Not investigated further this session — flagged rather than chased, since
it's low-severity (an analytics/tracing sidecar, not on the student- or
admin-facing request path) and genuinely unrelated to any change made
today. Root cause is most likely a credential drift between
`langfuse-staging`'s configured `DATABASE_URL`/password and whatever
`langfuse-db-staging`'s actual Postgres role password currently is —
possibly from an earlier password rotation that didn't reach both sides,
similar in shape to other credential-drift findings this session, but not
confirmed.

## Root Cause
Not yet determined.

## Prevention / Rule
Not yet determined — needs the root-cause investigation first.

## Solution

### Immediate Fix
None applied.

### Long-term Fix
Compare `langfuse-staging`'s configured Postgres credentials against
`langfuse-db-staging`'s actual role password (likely via `.env.staging`
and/or `docker/secrets/` on the VPS) and reconcile whichever side drifted.

## Prevention
- [ ] Configuration changes needed — reconcile langfuse DB credentials
- [ ] Monitoring/alerts to add — a restart-loop alert (e.g. `ServiceDown`
      already exists in principle via `up==0`, but a Prisma-migration
      crash-loop before the app ever binds its port may not trip a scrape
      failure the same way — worth checking whether `up{job=~"langfuse"}`
      is actually scraped at all)
- [ ] Documentation to update — none yet
- [ ] Code changes required — none expected, likely a secrets/env fix

## Related Issues
- None yet — first time noticed.

## References
- `docker-compose.staging.yml` — `langfuse`, `langfuse-db` services

---

**Resolved By:** Not yet — flagged only, no fix applied
**Time to Resolution:** N/A
