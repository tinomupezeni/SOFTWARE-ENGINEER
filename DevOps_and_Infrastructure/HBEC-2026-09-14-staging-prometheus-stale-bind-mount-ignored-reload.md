# Staging Prometheus's `alerts.yml` Bind Mount Was Orphaned From the Live File — `/-/reload` Silently Kept Serving Stale Rules

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
While deploying a fix to two alert rules (see the companion
`HBEC-2026-09-14-highllmlatency-alerts-query-enterprise-only-metrics.md`
entry), edited `monitoring/alerts.yml` directly on both production and
staging and triggered Prometheus's `/-/reload` endpoint on each. Production
picked up the change immediately; staging's `hbec-prometheus-staging`
kept evaluating the old rule set, even though `/-/reload` returned `200`
every time and gave no indication anything had failed.

## Symptoms
- `curl -X POST http://localhost:7090/-/reload` → `200 OK`.
- `GET /api/v1/rules` immediately afterward still showed the pre-edit
  rules (`HighLLMErrorRate` present, `HighLLMLatency` still on the old
  expression) — repeatable across multiple reload attempts and a few
  seconds' wait, ruling out a simple propagation delay.

## Environment Details
- **Server/Host:** hbca-vps, `hbec-prometheus-staging`
- **Services Affected:** Prometheus rule evaluation on staging only —
  production's `hbec-prometheus` was unaffected
- **Related Components:** `docker-compose.staging.yml`'s `prometheus`
  service bind mount for `monitoring/alerts.yml`
- **Time First Observed:** 2026-09-14

## Investigation Steps

### 1. Initial Diagnosis
Compared the file's content as seen from the host vs. from inside the
container:
```bash
docker exec hbec-prometheus-staging grep -n 'HighLLMErrorRate' /etc/prometheus/alerts.yml
# still present — but the host file had already been edited to remove it
```

### 2. Root Cause Analysis
```bash
stat -c '%Y %i' /home/winstontino/HBEC/monitoring/alerts.yml
docker exec hbec-prometheus-staging stat -c '%Y %i' /etc/prometheus/alerts.yml
```
Different inodes, and the container's copy was ~18 days older (`mtime`
~1.6M seconds behind the host file). The bind mount `docker inspect`
reported was the correct path
(`/home/winstontino/HBEC/monitoring/alerts.yml` → `/etc/prometheus/alerts.yml`),
but a Docker file-level bind mount attaches to a specific inode at
container-start time, not a live path lookup. If the host file at that
path is ever replaced via a temp-file-then-rename swap (which `git
checkout`/`git pull` does, rather than an in-place truncate-and-rewrite)
instead of edited in place, the running container's mount keeps pointing
at the old, now-orphaned inode — the path resolves to a new file on the
host, but the container never sees it until it's recreated.

Confirmed a plain `docker compose up -d --no-deps prometheus` does **not**
fix this: Compose only recreates a container when it detects a
configuration change, and a bind mount's *source path string* is
unchanged even though the file *content* behind it changed — so Compose
considers there to be nothing to do and leaves the stale container
running untouched.

### 3. Key Findings
- Production's `hbec-prometheus` did not have this problem — its mount's
  inode matched the host file exactly, meaning production's container has
  been recreated more recently than whatever git operation last replaced
  staging's `alerts.yml` on disk.
- `/-/reload`'s `200` response only confirms Prometheus successfully
  re-read *whatever file its existing file descriptor points at* — it
  provides zero signal about whether that file descriptor still
  corresponds to the current content at the nominal path. This makes the
  failure completely silent from the reload caller's point of view.

## Root Cause
A host-level file replace-via-rename (most likely an earlier `git
checkout`/`git pull` on staging's git-connected `/home/winstontino/HBEC`
checkout) swapped `monitoring/alerts.yml`'s inode without recreating the
`hbec-prometheus-staging` container, silently orphaning its bind mount.
Every `/-/reload` since then re-read the same stale, orphaned inode and
reported success.

## Prevention / Rule
**Guardrail:** After any edit to a bind-mounted config file that matters
for correctness (alert rules, in particular), verify the change actually
took effect by checking the *served* state (`GET /api/v1/rules`'s rule
body/health, not just the `/-/reload` HTTP status) rather than trusting
the reload call's status code alone. More structurally: prefer `docker
compose up -d --force-recreate <service>` over a bare `up -d` whenever a
bind-mounted file was edited outside of a full compose-driven deploy, since
`--force-recreate` doesn't depend on Compose noticing a content change it
has no way to see.

This closes the gap because the actual failure mode wasn't the edit
itself — it was trusting an HTTP `200` as proof of effect, when the
correct verification is checking the state that matters (the live rule
set) directly.

## Solution

### Immediate Fix
```bash
cd /home/winstontino/HBEC
docker compose --env-file .env.staging -f docker-compose.staging.yml \
  up -d --no-deps --force-recreate prometheus
```
Confirmed the container's `/etc/prometheus/alerts.yml` inode now matches
the host file, and `GET /api/v1/rules` shows the corrected rule set with
`health: ok`.

### Long-term Fix
None needed beyond the guardrail above — this specific staleness is
resolved by the recreate, and it self-corrects on any future full staging
redeploy (which always recreates containers).

## Prevention
- [x] Configuration changes needed — done (force-recreate)
- [ ] Monitoring/alerts to add — none planned; this is a low-frequency,
      now-understood operational gotcha rather than something worth its
      own alert
- [ ] Documentation to update — worth a one-line note in the deploy
      runbook: "after hand-editing a bind-mounted config file, use
      `--force-recreate`, not a bare `up -d`"
- [x] Code changes required — n/a, operational only

## Related Issues
- `HBEC-2026-09-14-highllmlatency-alerts-query-enterprise-only-metrics.md`
  — the alert-rule fix being deployed when this was discovered.

## References
- `docker-compose.staging.yml` — `prometheus` service bind mount
- `/home/winstontino/HBEC/monitoring/alerts.yml`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery
