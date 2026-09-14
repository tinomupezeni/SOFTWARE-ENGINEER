# Grafana, Postgres/Redis Exporters, and Jaeger Were Never Started on Production — Silently Gated Behind an Unused Compose Profile

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
While building observability in direct response to the 2026-09-13 AI outage
("all the AI went down and we didn't even know it"), found that four of the
six services meant to provide monitoring on production had never been
created at all — not stopped, not crashed, simply never instantiated by any
prior deploy. `docker ps -a` showed no `hbec-grafana`, `hbec-postgres-
exporter`, `hbec-redis-exporter`, or `hbec-jaeger` containers, not even in an
exited state. Only `prometheus` and `alertmanager` were running.

## Symptoms
- No Grafana dashboard reachable at all on production.
- Postgres and Redis had no exporter metrics feeding Prometheus, so any
  alert rule depending on `pg_up`/`redis_up`-style metrics was silently
  inert.
- No distributed tracing (Jaeger) despite being configured.
- None of this produced an obvious error anywhere — there was nothing
  crash-looping to notice in logs, just services that were never asked to
  exist.

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec/docker-compose.production.yml`
- **Services Affected:** `grafana`, `postgres-exporter`, `redis-exporter`,
  `jaeger`
- **Related Components:** `prometheus`, `alertmanager` (these two were
  already running correctly)
- **Time First Observed:** 2026-09-14

## Investigation Steps

### 1. Initial Diagnosis
```bash
docker ps -a | grep -E 'grafana|exporter|jaeger'
# (no output at all — not even exited containers)
```

### 2. Root Cause Analysis
```bash
awk '/^  [a-z_-]+:/{svc=$1} /profiles:/{p=1} p && /- monitoring/{print svc; p=0}' \
  docker-compose.production.yml
```
Confirmed `prometheus`, `grafana`, `alertmanager`, `redis-exporter`,
`postgres-exporter`, and `jaeger` all carry:
```yaml
profiles:
  - monitoring
```
Compose profiles are opt-in: a plain `docker compose up -d <service>` (the
pattern this deploy history consistently uses for recreating individual app
services) never starts a profiled service unless `--profile monitoring` is
passed explicitly. `prometheus` and `alertmanager` were up only because
someone had, at some earlier point, deliberately run the profile-qualified
command for those two specifically — the other four never got the same
treatment.

### 3. Key Findings
- This is a "silent by design" gap: Compose profiles produce no warning,
  error, or log line when a profiled service is simply never requested. The
  service doesn't fail to start — it's never asked to start.
- Verified `GRAFANA_ADMIN_PASSWORD` was already a real value in `/opt/hbec/.env`
  (not the insecure default), so once started Grafana came up correctly
  configured — the gap was purely "never launched," not misconfigured.

## Root Cause
Six services share a `profiles: [monitoring]` gate in
`docker-compose.production.yml`, but the deploy workflow this environment
actually uses (`docker compose up -d --no-deps <service>` per app service)
never invokes `--profile monitoring`, so any service under that gate that
wasn't started by a one-off manual command at some point in the past simply
never exists on the box.

## Prevention / Rule
**Guardrail:** Either remove the `profiles: [monitoring]` gate entirely (if
monitoring should always run alongside the app stack, which it should — this
incident is exactly why), or add a single documented `up` invocation for the
full stack (`docker compose --profile monitoring up -d`) that becomes the
one command anyone runs for a full-stack (re)deploy, with a comment directly
in `docker-compose.production.yml` next to the `profiles:` key pointing at
it. A profile that only some deploy commands know to pass is a guaranteed
future omission; removing the optionality removes the failure mode.

## Solution

### Immediate Fix
```bash
docker compose -f docker-compose.production.yml --profile monitoring \
  up -d --no-deps grafana postgres-exporter redis-exporter
docker compose -f docker-compose.production.yml --profile monitoring \
  up -d --no-deps jaeger
```
Confirmed all four `Up` via `docker ps`, and confirmed via a Prometheus
`up{}` query that all previously-known scrape targets
(`harness`, `postgres`, `redis`, `admin-backend`, `litellm`,
`student-backend`, `jaeger`) now read `1`.

### Long-term Fix
Remove the `profiles:` gate on these six services (or standardize the
deploy runbook on the profile-qualified command) so a future full-stack
bring-up can't silently omit them again.

## Prevention
- [ ] Configuration changes needed — drop the `profiles: [monitoring]` gate
      or fix the documented deploy command
- [x] Monitoring/alerts to add — the services themselves are the monitoring
      stack; now running
- [ ] Documentation to update — the deploy runbook should name the correct
      full-stack `up` command
- [ ] Code changes required

## Related Issues
- `HBEC-2026-09-13-production-litellm-config-drift-from-git.md` — same
  general incident (the 2026-09-13 AI outage) prompted both investigations;
  this is the "we didn't even know" observability gap the user asked to be
  addressed directly.

## References
- `/opt/hbec/docker-compose.production.yml`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** ~20m
