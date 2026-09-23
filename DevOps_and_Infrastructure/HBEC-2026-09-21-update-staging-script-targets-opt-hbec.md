# `update_staging.sh` Lives in the Staging Directory but Deploys to `/opt/hbec` (Production)

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Production + Staging (hbca-vps, same Docker host)
**Severity:** High (latent — not run this session, found while deploying a
routine feature manually)
**Status:** Resolved (2026-09-23) — see Update below. Left unfixed for 2 days
after being flagged; a production outage in that window
(`HBEC-2026-09-23-production-gateway-502-outage.md`) had its own postmortem
recommend `./update_staging.sh` by name as the safe canonical script to use
instead of raw `docker compose` — which would have pointed the next operator
straight at this one.

## Summary
While manually deploying the new Student Sync Status panel to staging (per
`docs/DEPLOYMENT.md`'s documented flow, `docker compose -f
docker-compose.staging.yml --env-file .env.staging build/up`), found four
deploy scripts sitting in the staging checkout (`/home/winstontino/HBEC/`):
`update_staging.sh`, `deploy_staging.sh`, `deploy_staging_fix.sh`,
`deploy_staging_proper.sh`. Only the last one is correct. `update_staging.sh`
— named indistinguishably from the others and the most likely one to be
reached for by name — `cd`s into `/opt/hbec` (production's directory, not
staging's), runs `sudo git reset --hard origin/master` there, then builds and
deploys using `docker-compose.staging.yml`.

Running it would force-reset production's pinned commit (`docker-compose.production.yml`
is image-only and intentionally does NOT track `master` directly — see
`HBEC/CLAUDE.md`'s CI/CD section) to the tip of `master`, then rebuild and
redeploy production's containers using the *staging* compose file's service
definitions.

## Symptoms
None observed — not run. Found by reading the script before running it,
prompted by wanting to confirm the correct manual-deploy invocation.

## Environment Details
- **Server/Host:** hbca-vps, `/home/winstontino/HBEC/` (staging checkout)
- **Services Affected:** would be all of production if run
- **Related Components:** `update_staging.sh`, `deploy_staging.sh`,
  `deploy_staging_fix.sh` (not fully audited — only `deploy_staging_proper.sh`
  was read in full and confirmed correct), `docker-compose.staging.yml`,
  `docker-compose.production.yml`
- **Time First Observed:** 2026-09-21, during manual staging deploy of the
  Student Sync Status feature

## Investigation Steps

### 1. Initial Diagnosis
Staging has no CD auto-deploy path in use for this session (deploying
manually per explicit instruction), so looked for the documented/existing
manual deploy script rather than hand-typing the full `docker compose`
invocation from `cd.yml`.

### 2. Root Cause Analysis
```bash
cat update_staging.sh
```
```bash
ssh hbca-vps << 'INNER_EOF'
    cd /opt/hbec
    sudo git reset --hard origin/master
    sudo docker compose -f docker-compose.staging.yml --profile workers build ...
    sudo docker compose -f docker-compose.staging.yml --profile workers up -d ...
INNER_EOF
```
`/opt/hbec` is production's directory (root-owned, confirmed by `HBEC/CLAUDE.md`'s
own VPS section). This script hard-resets it and deploys with the *staging*
compose file — from inside a script named and placed as if it operates on
staging. `deploy_staging_proper.sh`, sitting right next to it, does the
equivalent thing correctly (`cd /home/winstontino/HBEC`, no `sudo`, same repo
via `git pull`). Neither script passes `--env-file .env.staging` to `docker
compose`, so even the correct one would default to the plain `.env` file's
`TAG` — worth checking whether `.env`'s `TAG` still defaults away from
`latest` before this script is ever relied on again (see
`HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md`, the sibling
incident this same directory already produced once).

### 3. Key Findings
- Four similarly-named deploy scripts exist in the staging directory; only
  one was verified correct in this session.
- The dangerous one requires `sudo` to actually execute (`/opt/hbec` is
  root-owned), which likely explains why it hasn't caused damage yet — but
  that's an incidental barrier, not a designed one, and the `winstontino`
  user's sudo access wasn't checked.
- None of the four pass `--env-file .env.staging` explicitly, unlike the
  documented flow in `docs/DEPLOYMENT.md` and `cd.yml`'s own staging job.

## Root Cause
Script naming and directory placement implied scope (a script living in the
staging checkout, named `update_staging.sh`) that its actual content
contradicted (`cd /opt/hbec`) — most likely a copy-paste origin from an
earlier production-deploy script that was never adapted, or the reverse.
Nothing enforces that a script's `cd` target matches the directory it's
stored in.

## Prevention / Rule
**Guardrail:** Delete or rename the three unverified/incorrect scripts
(`update_staging.sh`, `deploy_staging.sh`, `deploy_staging_fix.sh`), leaving
only one canonical, correct staging-deploy script per environment directory —
this is a "which file do I run" hazard, and the fix is reducing to one
obviously-correct option, not documenting which of four to avoid. A script
that must never touch `/opt/hbec` should not exist inside
`/home/winstontino/HBEC/` at all, regardless of what it's named.

This wasn't done in this pass — flagged to the user rather than deleting
scripts on the VPS unprompted, since removing files outside the git repo on a
shared production host is a judgment call for the operator, not something to
do silently mid-feature-deploy.

## Solution

### Immediate Fix
None — not run, no changes made to the VPS scripts. Deployed this session's
feature using the verified-correct manual invocation instead
(`docker compose -f docker-compose.staging.yml --env-file .env.staging build/up`
directly, matching `deploy_staging_proper.sh` and `cd.yml`'s staging job).

### Long-term Fix
~~Audit and consolidate the four scripts down to one per environment; the
survivor should explicitly pass `--env-file .env.staging` (or `.env` for
prod) rather than relying on the default the CWD happens to pick up.~~ Done
— see Update below.

## Update (2026-09-23) — the three scripts removed

Re-verified each script's content fresh (not trusting this entry's own
2-day-old description) before deleting anything, since a raw
`docker compose` outage in the interim
(`HBEC-2026-09-23-production-gateway-502-outage.md`) made this more urgent,
not less — that outage's own postmortem named `./update_staging.sh` as the
recommended safe script, which would have sent the next operator straight
into this bug, likely worse: a `sudo git reset --hard` on production's
checkout, not just an orphaned container.

Confirmed all three matched or exceeded the original description:
- `update_staging.sh` — `cd /opt/hbec`, `sudo git reset --hard origin/master`,
  then staging compose build/up. Exactly as described.
- `deploy_staging.sh` — also targets `/opt/hbec`, via `scp` + `tar` extraction
  instead of git reset, same net effect.
- `deploy_staging_fix.sh` — a third copy of the same `/opt/hbec` bug, via
  `tar` extraction, not previously fully read in the original pass.

`deploy_staging_proper.sh` re-verified correct: `cd /home/winstontino/HBEC`
(the real staging directory), plain `git pull origin master`, no `sudo`. Its
missing `--env-file .env.staging` flag (noted in Root Cause Analysis above)
was fixed in a follow-up pass the same day: both `docker compose build` and
`up -d` invocations now pass `--env-file .env.staging` explicitly, matching
`docs/DEPLOYMENT.md` and `cd.yml`'s own staging job rather than relying on
whichever `TAG` the bare `.env` happens to default to. Confirmed
`.env.staging` exists at the expected path before wiring it in; permissions
(`-rwxrwxr-x`) preserved on rewrite.

Checked for cron jobs or other scripts referencing any of the three by name
before deleting — none found. Removed all three:
```bash
rm /home/winstontino/HBEC/update_staging.sh \
   /home/winstontino/HBEC/deploy_staging.sh \
   /home/winstontino/HBEC/deploy_staging_fix.sh
```
`/home/winstontino/HBEC/` now has exactly one staging-deploy script.

## Prevention
- [x] Configuration changes needed — the three unverified/incorrect scripts removed
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — this entry
- [ ] Code changes required — n/a (script content, not application code)

## Related Issues
- `HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md` — same
  directory, same host, a related but distinct staging/prod isolation gap
  (image tag namespace rather than script scope).

## References
- `/home/winstontino/HBEC/deploy_staging_proper.sh` (VPS, not in the git
  repo mirror checked out locally — read via SSH; the sole survivor)
- `HBEC/docs/DEPLOYMENT.md` §"Manual Backup"/staging deploy flow
- `HBEC/.github/workflows/cd.yml` (staging job's `--env-file .env.staging` usage)
- `HBEC-2026-09-23-production-gateway-502-outage.md` — the incident whose
  own postmortem made this fix urgent

---

**Resolved By:** Claude Sonnet 5 (flagged 2026-09-21 by Claude Sonnet 5;
resolved 2026-09-23)
**Time to Resolution:** 2 days from flagged to fixed
