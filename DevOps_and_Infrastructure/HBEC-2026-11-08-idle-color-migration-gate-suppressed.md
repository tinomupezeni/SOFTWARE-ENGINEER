# Idle-color deployment suppresses migration safety check failures

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Production deployment tooling review; target deployment in progress
**Severity:** High
**Status:** Investigating

## Summary
`manual-deploy-color.sh` invokes the expand-only migration checker with `|| true`. A checker failure therefore cannot stop the idle-color deployment, although both colors share the database and the live color may not tolerate a destructive migration.

## Symptoms
- The script continues to build and start the idle color after a failing `check-migrations.py --base` result.
- Its printed safety-gate message can be mistaken for an enforced gate.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** Blue/green deployment and shared databases
- **Related Components:** `scripts/deploy/manual-deploy-color.sh`, `scripts/deploy/check-migrations.py`
- **Time First Observed:** 2026-11-08 pre-deploy review

## Investigation Steps

### 1. Initial Diagnosis
Read the blue/green runbook and the manual deployment script before executing it.

### 2. Root Cause Analysis
The shell `|| true` converts the checker's nonzero exit into success.

### 3. Key Findings
- The current target adds three Alembic migrations and the checker reports 0 problems when run separately as a hard gate.
- The script's own gate would still continue if a future migration is rejected.

## Root Cause
An explicit failure-suppression operator was left on a release-critical migration check.

## Prevention / Rule
**Guardrail:** Remove `|| true` and require the migration checker to exit zero before the image build or Compose up step.

That makes a rejected migration stop the deployment while the live color is untouched.

## Solution

### Immediate Fix
For the 2026-11-08 deployment, ran `python3 scripts/deploy/check-migrations.py --base 4a10d5d2f153155dd2120c6bbbf94a145d2ab6c2` independently and required its zero exit (three files, zero problems) before invoking the playbook script.

### Long-term Fix
Remove the suppression in the script and add a regression test proving a failing checker prevents the build.

## Prevention
- [x] Current deployment separately gated
- [ ] Script suppression removed
- [ ] Regression gate added

## Related Issues
- Migrations 043–045 in HBEC commit `84167901f`.

## References
- HBEC `scripts/deploy/manual-deploy-color.sh`, `scripts/deploy/check-migrations.py`

---

**Resolved By:** Pending permanent script fix
**Time to Resolution:** Ongoing
