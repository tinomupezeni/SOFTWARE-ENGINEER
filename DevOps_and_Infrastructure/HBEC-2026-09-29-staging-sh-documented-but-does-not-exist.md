# `staging.sh` Is Documented in Two Places but Doesn't Exist on the VPS

**Date:** 2026-09-29
**Project:** HBEC
**Environment:** Staging (hbca-vps)
**Severity:** Low (a documentation/tooling gap, not a live incident)
**Status:** Investigating — flagged, not fixed

## Summary
Both `HBEC/CLAUDE.md` ("managed day-to-day with `./staging.sh
{up,down,logs,ps}`") and `docs/MANUAL_DEPLOY_PROMOTION.md` (Part 1, step 4:
`./staging.sh up --wait --wait-timeout 420 --remove-orphans`) reference a
`staging.sh` script at `/home/winstontino/HBEC/staging.sh`. It does not exist
on the VPS, and has never existed in the HBEC git repo's history
(`git log --all -- staging.sh` returns nothing) — it's excluded from
`scripts/deploy_to_staging.sh`'s rsync on purpose (`--exclude 'staging.sh'`),
implying it's meant to be a VPS-local, hand-maintained convenience wrapper
that was apparently never actually created there.

## Symptoms
Following `docs/MANUAL_DEPLOY_PROMOTION.md` literally today would fail at
Part 1 step 4 with "No such file or directory."

## Environment Details
- **Server/Host:** hbca-vps, `/home/winstontino/HBEC/`
- **Services Affected:** none directly — a documentation/tooling gap
- **Related Components:** `staging.sh`, `deploy_staging_proper.sh`,
  `scripts/deploy_to_staging.sh`
- **Time First Observed:** 2026-09-29, while verifying tooling for a new
  staging→production promotion runbook

## Investigation Steps

### 1. Initial Diagnosis
`docs/MANUAL_DEPLOY_PROMOTION.md` names `./staging.sh` as a required step.
Checked it actually exists before citing it in a new runbook.

### 2. Root Cause Analysis
```bash
ssh hbca-vps "ls -la /home/winstontino/HBEC/staging.sh"
# ls: cannot access '/home/winstontino/HBEC/staging.sh': No such file or directory
git log --all --oneline -- staging.sh   # (run locally in the HBEC repo) — no output
```
What actually exists in `/home/winstontino/HBEC/` today:
`deploy_staging_proper.sh` (the verified-correct staging deploy script per
`HBEC-2026-09-21-update-staging-script-targets-opt-hbec.md`'s Update),
`scripts/deploy_to_staging.sh` (meant to run from a local machine, rsyncs +
SSHs in), plus `deploy_master.sh` and `deploy.sh` — both unrelated to
staging and dangerous (see the companion entry filed the same day,
`HBEC-2026-09-29-deploy-master-and-deploy-sh-still-target-opt-hbec.md`).

### 3. Key Findings
- `staging.sh`'s documented interface (`up`/`down`/`logs`/`ps`) doesn't
  match any existing script's actual invocation shape — it was likely
  planned or used once locally and never committed/copied to this VPS,
  or was deleted at some point outside git.
- This session's actual staging deploy (2026-09-29, Custom Email Composer
  feature) used the verified-working invocation directly (`docker compose
  -f docker-compose.staging.yml --env-file .env.staging build/up
  --force-recreate`), not `staging.sh`, and it worked correctly.

## Root Cause
Documentation (`CLAUDE.md`, `docs/MANUAL_DEPLOY_PROMOTION.md`) describes a
convenience wrapper that was never actually placed on this VPS, or existed
once outside git and was later lost.

## Prevention / Rule
**Guardrail:** Either create `staging.sh` on the VPS matching the documented
`{up,down,logs,ps}` interface (a thin wrapper around
`docker compose -f docker-compose.staging.yml --env-file .env.staging
[--profile workers ...] $1`), or update both documents to stop referencing
it and use the direct `docker compose` invocation instead. Either closes the
gap; leaving the docs pointing at a nonexistent file is what actually causes
harm — the next operator following the runbook literally will stop cold at
that step with no explanation.

## Solution

### Immediate Fix
None — not created. The new staging→production runbook
(`HBEC/docs/STAGING_TO_PRODUCTION_RUNBOOK.md`) uses the verified direct
`docker compose` invocation instead of `./staging.sh`, and calls out this gap
explicitly so a future agent doesn't get stuck looking for the missing file.

### Long-term Fix
Operator decision: create the wrapper, or scrub the two references to it.

## Prevention
- [ ] Configuration changes needed — create `staging.sh` or remove the
  references (operator decision)
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — the new runbook works around this; `CLAUDE.md`
  and `docs/MANUAL_DEPLOY_PROMOTION.md` still need a decision either way
- [ ] Code changes required — n/a

## Related Issues
- `HBEC-2026-09-29-deploy-master-and-deploy-sh-still-target-opt-hbec.md` —
  found in the same tooling audit, same directory.

## References
- `HBEC/CLAUDE.md` (Service Map: "managed day-to-day with `./staging.sh`")
- `HBEC/docs/MANUAL_DEPLOY_PROMOTION.md` (Part 1, step 4)

---

**Resolved By:** Claude Sonnet 5 (flagged 2026-09-29, not yet resolved)
**Time to Resolution:** N/A — awaiting operator decision
