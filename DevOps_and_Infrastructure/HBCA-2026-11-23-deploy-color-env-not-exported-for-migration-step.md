# deploy-color.sh lost COLOR/IMAGE_TAG before the migration step

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps, first real CI-driven deploy)
**Severity:** High
**Status:** Resolved

## Summary
The first real GitHub-Actions-driven deploy run got through build, push, bring-up, and health checks, then failed at the migration step: `error while interpolating services.backend.image: required variable IMAGE_TAG is missing a value: required`.

## Symptoms
- `docker compose run --rm backend alembic upgrade head` failed immediately with a missing-variable interpolation error, despite the identical compose file working for `up -d` moments earlier in the same script run.

## Environment Details
- **Server/Host:** hbca-vps (self-hosted GitHub Actions runner)
- **Services Affected:** `ops/deploy/deploy-color.sh` (CI deploy pipeline)
- **Related Components:** `.github/workflows/deploy.yml`
- **Time First Observed:** 2026-11-23, first CI run after all prior bugs in this pipeline were fixed

## Investigation Steps

### 1. Initial Diagnosis
The `up -d` command two lines earlier, in the same script, used the identical compose file and succeeded — isolating the problem to something different about how the two `docker compose` invocations were called, not the compose file itself.

### 2. Root Cause Analysis
```bash
grep -n "^IMAGE_TAG=\|^COLOR=\|COLOR=\"\$COLOR\"" ops/deploy/deploy-color.sh
# COLOR="$COLOR" IMAGE_TAG="$IMAGE_TAG" \
#   docker compose ... up -d ...     <- only this line had them
# docker compose ... run --rm backend alembic upgrade head   <- this one didn't
```

### 3. Key Findings
- `COLOR="$COLOR" IMAGE_TAG="$IMAGE_TAG" command` is an inline, single-command environment assignment in bash — it does not persist to later commands in the script.
- Manual verification testing (done just before this CI run, to validate the previous round of fixes) never caught this, because every manual step was run as a separate `ssh` invocation with `COLOR=... IMAGE_TAG=...` explicitly re-exported by hand each time — accidentally providing the exact thing the real script was missing.

## Root Cause
An inline env-var prefix was mistaken for a script-wide export.

## Prevention / Rule
**Guardrail:** In any deploy script that calls `docker compose` more than once with the same required variables, `export` those variables once near the top of the script rather than prefixing them inline on individual commands — inline prefixes are easy to forget to repeat, and nothing fails until the specific command that's missing them actually runs.

A second, process-level guardrail: when manually verifying a script meant to run unattended, run the *actual script* (or a faithful copy of its exact command sequence) rather than its individual commands typed out separately — typing each command by hand with "obviously needed" variables re-supplied can mask exactly this class of bug.

## Solution

### Immediate Fix
`export COLOR IMAGE_TAG` once, right after `IMAGE_TAG` is computed, removing the inline prefix from the `up -d` line (now redundant).

### Long-term Fix
None further needed.

## Prevention
- [x] Configuration changes needed — script fixed
- [ ] Monitoring/alerts to add
- [x] Documentation to update — `docs/deploy/RUNBOOK.md`
- [x] Code changes required

## Related Issues
- Part of the same deploy-pipeline bug-fixing session as `HBCA-2026-11-23-deploy-workflow-bootstrap-arg-and-yaml-syntax.md`.

## References
- `ops/deploy/deploy-color.sh`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~10 minutes
