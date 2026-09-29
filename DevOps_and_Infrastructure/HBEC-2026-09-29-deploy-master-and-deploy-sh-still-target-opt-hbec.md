# `deploy_master.sh` and `deploy.sh` Survived the 09-23 Cleanup — Both Still Hard-Target `/opt/hbec` (Production) From the Staging Checkout

**Date:** 2026-09-29
**Project:** HBEC
**Environment:** Staging + Production (hbca-vps, same Docker host)
**Severity:** Critical (latent — not run this session, found while researching
material for a new staging→production promotion runbook)
**Status:** Investigating — flagged to the user, not deleted (see Prevention)

## Summary
`HBEC-2026-09-21-update-staging-script-targets-opt-hbec.md` found and (on
2026-09-23) removed three scripts sitting in the staging checkout
(`/home/winstontino/HBEC/`) that actually deployed to production's directory
(`/opt/hbec`): `update_staging.sh`, `deploy_staging.sh`,
`deploy_staging_fix.sh`. That cleanup verified only those three by name and
declared `/home/winstontino/HBEC/` down to "exactly one staging-deploy
script" (`deploy_staging_proper.sh`).

That was wrong. Two more scripts with the *same* bug, under different names,
are still sitting in that exact directory today: `deploy_master.sh` and
`deploy.sh`. Neither was read in the 09-21/09-23 investigation. Both are
worse than any of the three that were removed.

## Symptoms
None observed — not run. Found by reading every `*.sh` file in the staging
checkout while building a general deploy runbook, rather than assuming the
09-23 cleanup was exhaustive.

## Environment Details
- **Server/Host:** hbca-vps, `/home/winstontino/HBEC/` (staging checkout)
- **Services Affected:** would be all of production, if either script is run
- **Related Components:** `deploy_master.sh`, `deploy.sh`,
  `docker-compose.production.yml`, `/opt/hbec`
- **Time First Observed:** 2026-09-29

## Investigation Steps

### 1. Initial Diagnosis
Was assembling a step-by-step staging→production promotion runbook and
wanted to confirm what deploy tooling actually exists on the VPS today,
rather than trusting `docs/MANUAL_DEPLOY_PROMOTION.md`'s references at face
value. Listed every `.sh` file under `/home/winstontino/HBEC/` and its
`scripts/` subdirectory.

### 2. Root Cause Analysis
`deploy_master.sh` (78 lines, staging checkout root, last modified
2026-09-10 — predates even the 09-21 finding):
```bash
PROJECT_DIR="/opt/hbec"
DOCKER_COMPOSE_FILE="docker-compose.production.yml"
...
cd $PROJECT_DIR
git fetch origin main
git reset --hard origin/main          # hard-resets PRODUCTION's checkout
docker compose -f $DOCKER_COMPOSE_FILE build
docker compose -f $DOCKER_COMPOSE_FILE run --rm student-backend python manage.py migrate
docker compose -f $DOCKER_COMPOSE_FILE run --rm admin-backend python manage.py migrate
docker compose -f $DOCKER_COMPOSE_FILE --profile workers up -d --wait --remove-orphans
```
This is a fully self-contained "master" pipeline that bypasses every real
safety gate the actual pipeline has: no `preflight-secrets.sh`, no
`verify-service-links.sh`, no `TAG=sha-<commit>` pinning (builds whatever
`origin/main` resolves to *at the moment it runs*, with no staging
verification step at all), no `image-tags.sh` retention. It has its own
health-check-gated auto-rollback loop, which makes it look authoritative and
safe to someone skimming it — but the standard it enforces (`curl` returns
200) is exactly what `docs/MANUAL_DEPLOY_PROMOTION.md` already documents as
insufficient ("Health checks and log-scanning are necessary but not
sufficient — they catch crashes, not silently-wrong behavior").

`deploy.sh` (34 lines, staging checkout root, same mtime) is worse — it's
meant to run from a **local machine**, not the VPS:
```bash
tar -czf .deploy/repo.tar.gz --exclude=.git ... .    # archives local CWD as-is
scp .deploy/repo.tar.gz hbca-vps:/tmp/repo.tar.gz
ssh hbca-vps << 'EOF'
    sudo mv /tmp/repo.tar.gz /opt/hbec/repo.tar.gz
    cd /opt/hbec
    sudo tar -xzf repo.tar.gz
    sudo docker build -t ghcr.io/rest-creator/hbec-student-backend:latest ./STUDENT/hbec_backend
    ... (6 more images, all tagged :latest)
    sudo docker compose -f docker-compose.production.yml --profile workers up -d --remove-orphans
EOF
```
It ships **whatever is on the local machine's disk** — not `git archive`,
plain `tar` over the working directory, so uncommitted changes go too — into
`/opt/hbec`, builds every image tagged `:latest` (the exact tag
`HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md` already showed
gets silently overwritten by staging builds on this same host), and deploys
straight to production with no health gate, no rollback, no verification of
any kind.

### 3. Key Findings
- The 09-23 cleanup checked for cron jobs/references to the *three named
  scripts it removed* — it did not enumerate every `.sh` file in the
  directory, so these two were never in scope of that check.
- Both scripts require `sudo` to actually reach `/opt/hbec` (root-owned),
  same incidental (not designed) barrier the original entry noted for
  `update_staging.sh`. `winstontino`'s sudo access was still not checked.
- `deploy_master.sh` in particular reads as a *more* complete, more
  professional-looking pipeline than the real one (it has retries, rollback,
  a health gate) — which makes it the more dangerous of the two to stumble
  on: it looks like "the good one," not an obvious mistake.

## Root Cause
Same root cause as the 09-21 entry, restated because it recurred: nothing
enforces that a script sitting in the staging checkout only ever touches
staging. The 09-23 fix addressed the three scripts a targeted grep/review
found, not the actual invariant ("no script in this directory may reference
`/opt/hbec`").

## Prevention / Rule
**Guardrail:** `/home/winstontino/HBEC/` should contain exactly one deploy
script, full stop — audited by listing every `*.sh` file in the directory
tree (not by name-matching against a known-bad list) and confirming none of
them reference `/opt/hbec`, `docker-compose.production.yml`, or
`origin/main`. A one-line CI-adjacent check (a pre-commit hook or a cron job
on the VPS itself: `grep -rl '/opt/hbec' /home/winstontino/HBEC/*.sh
/home/winstontino/HBEC/scripts/*.sh`, alert if non-empty) would have caught
both of these the same way it would have caught the original three.

This closes the gap the 09-23 fix left open: a name-based audit only ever
proves the names you checked are safe.

## Solution

### Immediate Fix
None — not run, nothing deleted. Per the same judgment call the 09-21 entry
made: removing files outside the git repo on a shared production host is the
operator's call, not something to do silently while researching an unrelated
task.

### Long-term Fix
Delete or move `deploy_master.sh` and `deploy.sh` out of
`/home/winstontino/HBEC/` (same remedy as 09-23's three), and run the
directory-wide grep above as a one-time full audit rather than trusting any
prior "down to one script" claim — including this entry's own, until that
grep comes back empty.

## Prevention
- [ ] Configuration changes needed — delete/move the two scripts (awaiting
  operator decision)
- [ ] Monitoring/alerts to add — a `/opt/hbec` grep across
  `/home/winstontino/HBEC/*.sh` as a periodic check
- [x] Documentation to update — this entry; the new staging→production
  runbook (`HBEC/docs/STAGING_TO_PRODUCTION_RUNBOOK.md`) names both scripts
  explicitly as DO NOT RUN
- [ ] Code changes required — n/a (script content, not application code)

## Related Issues
- `HBEC-2026-09-21-update-staging-script-targets-opt-hbec.md` — the original
  finding; this entry is its direct sequel, found because that one's fix
  wasn't as exhaustive as it concluded.
- `HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md` — the
  `:latest`-tag collision `deploy.sh` would reproduce if ever run.

## References
- `/home/winstontino/HBEC/deploy_master.sh`, `/home/winstontino/HBEC/deploy.sh`
  (VPS only, not in the git repo mirror — read via SSH)
- `HBEC/docs/MANUAL_DEPLOY_PROMOTION.md`, `HBEC/docs/DEPLOYMENT.md` — the
  actual, safe promotion path

---

**Resolved By:** Claude Sonnet 5 (flagged 2026-09-29, not yet resolved)
**Time to Resolution:** N/A — awaiting operator decision on deletion
