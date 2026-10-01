# Editing docker-compose.production.yml in Git and Pushing Never Reaches Production — It's Not a Git Checkout

**Date:** 2026-10-01
**Project:** HBEC
**Environment:** Production
**Severity:** Medium (caught before any real functional impact — the symptom was "new env var still blank," not an outage)
**Status:** Resolved

## Summary
Adding four new `IMAP_*` environment variable passthroughs to
`docker-compose.production.yml`, committing, and pushing to GitHub had zero
effect on production: the container's actual runtime environment still had
none of the new variables after a full `docker compose up` recreate.
Root cause: `/opt/hbec` is a hand-maintained, non-git directory (five fixed
files per its own documentation), not a git clone — pushing to GitHub only
ever updates the repo and (if also pulled there) staging's git clone at
`/home/winstontino/HBEC`. Production's own copy of the compose file has to
be copied over by hand, every time.

## Symptoms
- `docker-compose.production.yml` updated locally, committed, pushed.
- Production `.env` updated with the new variable values.
- `docker compose up -d --no-deps --wait student-backend student-worker`
  reported `Recreate` → `Recreated` → `Healthy` for both containers —
  looked completely successful.
- `docker exec hbec-student-backend env | grep IMAP_` returned nothing.
  `poll_email_bounces()` run directly still logged "IMAP not configured,
  skipping" even though `.env` definitely had real values.

## Environment Details
- **Server/Host:** Production VPS, `/opt/hbec`
- **Services Affected:** `student-backend`, `student-worker` (the two
  services the new `IMAP_*` passthrough was added to)
- **Related Components:** `docker-compose.production.yml`,
  `/opt/hbec/.env`
- **Time First Observed:** Immediately, while verifying the change live
  rather than trusting the "Healthy" status alone

## Investigation Steps

### 1. Initial Diagnosis
`.env` on production was confirmed correct (`grep -E '^IMAP_' /opt/hbec/.env`
showed the right keys and non-empty values). The container's own environment
was checked directly next, rather than assuming the compose file in the repo
was what was actually running.

### 2. Root Cause Analysis
```bash
grep -c 'IMAP_HOST' /opt/hbec/docker-compose.production.yml
# 0 — the live file has never seen this change at all
```
Confirmed `/opt/hbec` has no `.git` directory — it is populated and updated
by hand, exactly as `HBEC/CLAUDE.md`'s own VPS section already documents
("Container-only — 5 files at `/opt/hbec/`"). A git push only reaches
GitHub and whatever actually has that remote cloned (the repo itself, and
staging's `/home/winstontino/HBEC`) — never production.

### 3. Key Findings
- `docker compose up`'s "Recreate"/"Healthy" output is not evidence that the
  *intended* config change took effect — only that compose decided something
  about the resolved config differed from the running container and acted on
  it. It says nothing about whether the compose *file itself* was the one
  actually edited.
- This is a narrower instance of a pattern this codebase has already
  documented once before for `.env`/`.env.staging` drift
  (`HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md`): anything
  that lives only in git and needs to reach `/opt/hbec` requires an explicit,
  manual copy step — there is no pull, sync, or CI job that does it.

## Root Cause
`/opt/hbec` is not a git working directory. Editing and pushing
`docker-compose.production.yml` updates the GitHub repo and any git clone of
it (including staging's), but production's actual copy of that file is
static until someone copies the new version over by hand.

## Prevention / Rule
**Guardrail:** After any edit to `docker-compose.production.yml`, verify the
*live* file on `/opt/hbec` reflects the change (`grep` for the new key, or
diff the local file against a copy pulled from the VPS) before relying on a
`docker compose up` recreate to apply it — never trust "Recreated/Healthy"
alone as proof the intended change landed. The existing
`docs/STAGING_TO_PRODUCTION_RUNBOOK.md` should gain an explicit line for
this: a compose-file edit (not just an image/tag change) needs the file
itself copied to `/opt/hbec` first.

This closes the gap because the actual failure mode is "edited the wrong
copy of the file" — checking the live file directly, rather than inferring
success from compose's own recreate messaging, catches that mismatch
immediately instead of silently shipping a no-op.

## Solution

### Immediate Fix
```bash
scp docker-compose.production.yml hbca-vps:/tmp/docker-compose.production.yml
ssh hbca-vps "diff /tmp/docker-compose.production.yml /opt/hbec/docker-compose.production.yml"
# confirmed only the intended 8-line diff, nothing unexpected
ssh hbca-vps "sudo cp /opt/hbec/docker-compose.production.yml /opt/hbec/docker-compose.production.yml.bak-<timestamp> \
  && sudo cp /tmp/docker-compose.production.yml /opt/hbec/docker-compose.production.yml"
```
Recreated `student-backend`/`student-worker` again afterward; the new
environment variables were then present in the container
(`docker exec hbec-student-backend env | grep IMAP_` showed all four).

### Long-term Fix
No code change — this is a process gap. Flagged in Prevention above:
add an explicit "copy the compose file to `/opt/hbec` first" step to the
runbook for any future compose-structure change (not just image tag
promotions, which already have the correct digest-pinning discipline
documented).

## Prevention
- [ ] Add an explicit step to `docs/STAGING_TO_PRODUCTION_RUNBOOK.md`:
      "a compose *structure* change (new/removed env vars, new service)
      needs the file copied to `/opt/hbec` by hand — a git push/pull never
      reaches it."
- [x] Verified live (not just container-health) immediately after this
      exact mistake, catching it in the same session rather than leaving
      it to be discovered later.
- [ ] Consider a small drift-check script (`diff` the repo's compose file
      against the one on each real environment) as a periodic/pre-deploy
      check, mirroring `check_runtime_secret_drift.py`'s own purpose for
      a different class of drift.

## Related Issues
- `HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md` — a
  different drift class (image tag collision) with the same root shape:
  staging and production's actual deployed state can silently diverge from
  what git says, because neither is a live git checkout.

## References
- `/opt/hbec/docker-compose.production.yml`
- `docs/STAGING_TO_PRODUCTION_RUNBOOK.md`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Caught and fixed within the same session, before any functional impact (the symptom was a feature still no-op'ing, not an outage).
