# `deploy_master.sh` and `deploy.sh` Survived the 09-23 Cleanup — Both Committed to Git, Both Hard-Target `/opt/hbec` (Production)

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
`deploy_staging_fix.sh`. Those three were VPS-local, never committed to git.
That cleanup verified only those three by name and declared
`/home/winstontino/HBEC/` down to "exactly one staging-deploy script"
(`deploy_staging_proper.sh`).

That was wrong, and worse than the original finding: two more scripts with
the *same* `/opt/hbec`-targeting bug exist under different names —
`deploy_master.sh` and `deploy.sh` — and unlike the three that were removed,
**these are actually committed to the HBEC git repository itself**
(`git ls-files` confirms both; last touched by real commits `d653b78c`
"fix(payments): resolve ZB Bank webhook lockout..." and `4e8763a0` "chore:
push full codebase for testing"). They sit at the repo root and are present
in **every checkout** — this machine's local clone, the staging VPS
directory, and presumably anyone else's clone — not just one VPS directory.
Deleting them from the VPS alone would not fix this: the next `git pull`
brings them right back. The actual fix has to be a commit.

## Symptoms
None observed — not run. Found by reading every `*.sh` file in the staging
checkout while building a general deploy runbook, rather than assuming the
09-23 cleanup was exhaustive.

## Environment Details
- **Server/Host:** the HBEC git repository itself (root path) — present on
  hbca-vps in both `/home/winstontino/HBEC/` and (via `.gitignore` not
  excluding it) potentially `/opt/hbec` too, plus every local clone
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
- **The "requires sudo" mitigation the 09-21 entry relied on for
  `update_staging.sh` does not apply here.** `ls -la /opt/hbec/deploy_master.sh
  /opt/hbec/deploy.sh` on the live VPS shows both owned by
  `winstontino:winstontino`, `-rwxrwxr-x` — the *staging* user, not root.
  `winstontino` can read, overwrite, or execute either file in
  `/opt/hbec` with no `sudo` at all. Whether the `docker`/`git` commands
  *inside* them need `sudo` is a separate question the file permissions
  don't answer.
- **`/opt/hbec` itself does not match `HBEC/CLAUDE.md`'s description**
  ("Container-only — 5 files... root-owned"). The live directory has a full
  git checkout (`.git`, world-writable: `drwxrwxrwx`), complete source
  trees for every service, and >200 stray files (patch scripts, `.env.bak-*`
  secret backups, screenshots, multi-hundred-KB logs) — the overwhelming
  majority owned by `winstontino`, not root. This is a large enough gap from
  its own documentation that it's filed as its own, separate, higher-severity
  entry: see `HBEC-2026-09-29-opt-hbec-is-not-container-only-winstontino-owns-most-of-it.md`.
- `deploy_master.sh` in particular reads as a *more* complete, more
  professional-looking pipeline than the real one (it has retries, rollback,
  a health gate) — which makes it the more dangerous of the two to stumble
  on: it looks like "the good one," not an obvious mistake.

## Root Cause
Same root cause as the 09-21 entry, restated because it recurred and is now
known to be worse: nothing enforces that a script referencing `/opt/hbec`
can't exist in the repository at all. The 09-23 fix addressed the three
VPS-local scripts a targeted review found; it never checked whether the git
repo itself carried the same bug, so these two were invisible to that
cleanup by construction, not by oversight.

## Prevention / Rule
**Guardrail:** `git grep -l '/opt/hbec'` (or equivalent) should be a CI
check on this repo — any `.sh` file matching it outside `docker-compose.production.yml`/
`deployment/`/`docs/` itself is almost certainly a script that must never be
run from anywhere but a deliberate, reviewed production-deploy context. A
one-line pre-commit or CI grep would have caught both of these at the commit
that introduced them (`d653b78c`, `4e8763a0`), long before they reached
staging or production checkouts at all.

This closes the gap the 09-23 fix left open twice over: a name-based audit
only proves the names you checked are safe, and a VPS-only audit can't see
a hazard that's actually committed to the repository.

## Solution

### Immediate Fix
None yet — flagged to the user rather than deleting unilaterally, since this
is a real commit to shared history, not an ad-hoc VPS file. Removing them
needs a real `git rm` + commit (and then re-pulling on both the staging VPS
checkout and any other clone), not a one-off `rm` on the VPS — that would
only mask the problem until the next `git pull`.

### Long-term Fix
`git rm deploy.sh deploy_master.sh`, commit, push, and re-pull on both VPS
checkouts. Add the CI grep guardrail above so a reintroduction is caught
before merge, not found again by manual audit.

## Prevention
- [ ] Configuration changes needed — `git rm` both scripts (awaiting
  operator decision — this is a real commit, not a VPS file cleanup)
- [ ] Monitoring/alerts to add — CI grep for `/opt/hbec` outside the
  expected config/docs paths
- [x] Documentation to update — this entry; the new staging→production
  runbook (`HBEC/docs/STAGING_TO_PRODUCTION_RUNBOOK.md`) names both scripts
  explicitly as DO NOT RUN
- [ ] Code changes required — the `git rm` above, once approved

## Related Issues
- `HBEC-2026-09-21-update-staging-script-targets-opt-hbec.md` — the original
  finding; this entry is its direct sequel, found because that one's fix
  wasn't as exhaustive as it concluded.
- `HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md` — the
  `:latest`-tag collision `deploy.sh` would reproduce if ever run.
- `HBEC-2026-09-29-opt-hbec-is-not-container-only-winstontino-owns-most-of-it.md`
  — checking these two files' permissions on the live VPS is what surfaced
  this broader, more severe finding.

## References
- `deploy_master.sh`, `deploy.sh` — tracked at the HBEC repo root; present
  in this local clone, `/home/winstontino/HBEC/`, and `/opt/hbec/`
- `HBEC-2026-09-29-opt-hbec-is-not-container-only-winstontino-owns-most-of-it.md`
  — the broader finding this one surfaced
- `HBEC/docs/MANUAL_DEPLOY_PROMOTION.md`, `HBEC/docs/DEPLOYMENT.md` — the
  actual, safe promotion path

---

**Resolved By:** Claude Sonnet 5 (flagged 2026-09-29, not yet resolved)
**Time to Resolution:** N/A — awaiting operator decision on deletion
