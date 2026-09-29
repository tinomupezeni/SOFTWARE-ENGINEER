# `/opt/hbec` Is Not "Container-Only, 5 Files, Root-Owned" — It's a Full Git Checkout, Mostly Owned by the Staging User

**Date:** 2026-09-29
**Project:** HBEC
**Environment:** Production (hbca-vps, `/opt/hbec`)
**Severity:** Critical (latent — no exploitation observed; a documentation
and access-control gap found while building a deploy runbook)
**Status:** Investigating — flagged to the user, nothing changed

## Summary
`HBEC/CLAUDE.md`'s VPS section states production is "Container-only — 5
files at `/opt/hbec/`: `docker-compose.production.yml`, `.env`,
`docker/init-db.sql`, `docker/keys/jwt_*.pem`, `litellm_config.yaml`," and a
prior bug entry (`HBEC-2026-09-21-update-staging-script-targets-opt-hbec.md`)
relied on `/opt/hbec` being "root-owned" as (an acknowledged incidental, not
designed) barrier against a dangerous script being run from there.

Neither is true today. `sudo ls -la /opt/hbec/` shows a full git checkout —
`.git` (mode `drwxrwxrwx`, world-writable), complete source trees for every
service (`ADMIN/`, `STUDENT/`, `AGENTIC_HARNESS/`, `SCHOOLS/`, `PAYMENTS/`,
`NOTIFICATIONS/`), documentation, scripts, and well over 200 other files —
ad-hoc patch scripts (`patch_*.py`, `fix_*.js`), multiple `.env.bak-*`
**secret backups**, `docker-compose.production.yml.bak-*` (5+ copies),
multi-hundred-KB build/deploy logs, screenshots, a `.claude/` config
directory and three dated `.claude-backup-*` directories, `.pytest_cache`,
and the two dangerous scripts documented separately
(`HBEC-2026-09-29-deploy-master-and-deploy-sh-still-target-opt-hbec.md`).

**The overwhelming majority of this — including `deploy_master.sh`,
`deploy.sh`, `.env.bak-*`, and the `.git` directory itself — is owned by
`winstontino:winstontino`**, not root. Only a handful of files/directories
are root-owned: `docker-compose.production.yml` itself, one `.env` backup,
`.deploy/`, `examiner-reports/`, and `scratch2.py`.

## Symptoms
None observed as a live incident. Found while verifying deploy tooling for
a new staging→production promotion runbook — specifically, while checking
whether `deploy_master.sh`/`deploy.sh`'s "requires sudo to reach
`/opt/hbec`" mitigation (claimed by the 09-21 entry for a related, smaller
finding) still held.

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec`
- **Services Affected:** all of production, potentially — this is the
  directory `docker-compose.production.yml` and every promotion command in
  `docs/DEPLOYMENT.md`/`docs/MANUAL_DEPLOY_PROMOTION.md` operates from
- **Related Components:** file ownership/permissions on `/opt/hbec`,
  `HBEC/CLAUDE.md`'s VPS section, every deploy script that assumes
  root-only access there
- **Time First Observed:** 2026-09-29

## Investigation Steps

### 1. Initial Diagnosis
Checking whether `deploy_master.sh`/`deploy.sh` (see the companion bug
entry) actually needed `sudo` to be dangerous, since the 09-21 entry treated
"requires sudo" as a real (if incidental) barrier for a similar case.

### 2. Root Cause Analysis
```bash
ssh hbca-vps "sudo ls -la /opt/hbec/deploy.sh /opt/hbec/deploy_master.sh"
# -rwxrwxr-x 1 winstontino winstontino 2765 Sep 19 13:19 /opt/hbec/deploy_master.sh
# -rwxrwxr-x 1 winstontino winstontino 1418 Sep 19 13:19 /opt/hbec/deploy.sh

ssh hbca-vps "sudo ls -la /opt/hbec/"
# ~230 entries; drwxrwxrwx .git; ADMIN/, STUDENT/, AGENTIC_HARNESS/, SCHOOLS/,
# PAYMENTS/, NOTIFICATIONS/ full source trees; multiple .env.bak-*;
# docker-compose.production.yml.bak-* (5+); patch_*.py, fix_*.js;
# .claude/, three .claude-backup-*/ dirs; near-total winstontino ownership
```
Neither file requires `sudo` for `winstontino` to read, overwrite, or
execute — the ownership itself grants that. `sudo` would only gate whatever
*inside* the scripts needs root (e.g. `docker compose` if the Docker socket
requires it), which is a separate, narrower question than "can this script
be modified or run at all."

### 3. Key Findings
- `CLAUDE.md`'s "5 files, container-only" description and the "root-owned"
  assumption other bug entries built on (`HBEC-2026-09-21-update-staging-script-targets-opt-hbec.md`)
  are both stale, possibly since before this VPS's current layout — or were
  never fully accurate and no one had reason to check until now.
- `.env.bak-*` files sitting in a directory the staging user can read are a
  secrets-exposure surface distinct from the deploy-script hazard — same
  root cause (over-broad ownership), different blast radius (credential
  leakage vs. arbitrary production deploy).
- The `.git` directory being `drwxrwxrwx` (world-writable) on a production
  host is independently unusual and worth its own scrutiny — not
  investigated further in this pass.
- This was found as a side effect of researching a documentation task, not
  a targeted security review — a real review of `/opt/hbec`'s actual
  permission model was out of scope here and is recommended as a follow-up.

## Root Cause
Not yet determined with certainty — candidates, not investigated further in
this pass:
1. `/opt/hbec` may have been set up or repeatedly patched by `winstontino`
   directly (with `sudo` per-command) rather than the directory itself
   being properly root-owned end-to-end, so files created mid-session
   inherited the creating user's ownership instead of root's.
2. `HBEC/CLAUDE.md`'s VPS section may simply have never been verified
   against the live host after initial setup, and drifted silently as ad
   hoc production fixes accumulated files there over time (the dated
   `.claude-backup-*` directories and patch scripts suggest exactly this
   kind of accretion).

## Prevention / Rule
**Guardrail:** This needs a real decision from the operator, not a code
fix — the two candidates above have different correct remedies (re-securing
ownership vs. accepting the current model and updating the documentation to
match reality, whichever is actually true). At minimum:
- Update `HBEC/CLAUDE.md`'s VPS section to describe what's actually there,
  or restore it to match what the section describes — whichever is the
  intended state.
- Any bug entry or runbook step that relies on "`/opt/hbec` is root-owned"
  as a safety property (this includes the 09-21 entry and the new
  `docs/STAGING_TO_PRODUCTION_RUNBOOK.md`) should treat that as **not
  currently true** until this is resolved.

## Solution

### Immediate Fix
None — flagged only. This is production infrastructure access control; not
something to change unilaterally mid-documentation-task.

### Long-term Fix
Operator decision required:
1. Decide the intended ownership/access model for `/opt/hbec` (who should
   be able to write there, and why `winstontino` currently can).
2. Either restore root ownership across the directory (and fix whatever
   workflow currently requires `winstontino` to write there directly), or
   formally accept the current model and update `CLAUDE.md` + every bug
   entry that assumed otherwise.
3. Separately: audit and clear the `.env.bak-*` secret backups and the
   `.claude-backup-*` directories for anything that shouldn't persist on a
   production host indefinitely.
4. Separately: investigate why `.git` is world-writable.

## Prevention
- [ ] Configuration changes needed — ownership/access model decision
  (operator)
- [ ] Monitoring/alerts to add — a periodic `stat`-based check that
  `/opt/hbec`'s core files stay root-owned, if that's the intended model
- [x] Documentation to update — `HBEC/CLAUDE.md`'s VPS section needs to
  match whatever the operator decides is correct
- [ ] Code changes required — n/a

## Related Issues
- `HBEC-2026-09-29-deploy-master-and-deploy-sh-still-target-opt-hbec.md` —
  the finding that led here.
- `HBEC-2026-09-21-update-staging-script-targets-opt-hbec.md` — relied on
  the now-disproven "root-owned" assumption.

## References
- `HBEC/CLAUDE.md` (VPS section: "Container-only — 5 files... root-owned")
- `HBEC/docs/DEPLOYMENT.md`, `HBEC/docs/MANUAL_DEPLOY_PROMOTION.md` — every
  command targeting `/opt/hbec` assumes the documented model

---

**Resolved By:** Claude Sonnet 5 (flagged 2026-09-29, not yet resolved)
**Time to Resolution:** N/A — awaiting operator decision
