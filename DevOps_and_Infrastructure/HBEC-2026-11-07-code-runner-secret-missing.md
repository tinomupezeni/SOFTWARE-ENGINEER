# Code runner secret missing from VPS environment

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** Staging deployment on VPS
**Severity:** High
**Status:** Resolved

## Summary
The blue-green staging deployment for `bc9eabef1` stopped before recreating the
inactive color because Compose requires `CODE_RUNNER_SECRET`, but the VPS
`/opt/hbec/.env` did not contain it.

## Symptoms
- The deployment script built the images successfully.
- Compose configuration failed before startup:
  `required variable CODE_RUNNER_SECRET is missing a value`.
- Existing production and inactive-color containers were not restarted.

## Environment Details
- **Server/Host:** HBCA VPS
- **Services Affected:** Code runner, harness and color deployment gate
- **Related Components:** `docker-compose.production.yml`,
  `scripts/deploy/ensure-code-runner-secret.sh`
- **Time First Observed:** 2026-11-07

## Investigation Steps

### 1. Initial Diagnosis
The deployment output was inspected after the command exited non-zero. The
failure occurred while Compose interpolated the code-runner environment.

### 2. Root Cause Analysis
The VPS checkout had the current deployment script after being pinned to the
requested commit, but the manually maintained `/opt/hbec/.env` predated the
new required variable.

### 3. Key Findings
- `CODE_RUNNER_SECRET` was absent from `/opt/hbec/.env`.
- `docker-compose.production.yml` declares it as required.
- No green containers were recreated by the failed attempt.

## Root Cause
The manually maintained VPS environment was not updated when the code-runner
service became a required Compose dependency.

## Prevention / Rule
**Guardrail:** Run `scripts/deploy/ensure-code-runner-secret.sh .env` before
every Compose config or deployment operation.

The deployment script already contains this guard, and the VPS was repaired
with it; future deploys must fail at the preflight if the guard is removed or
if the environment file is not writable.

## Solution

### Immediate Fix
Generated one persistent random `CODE_RUNNER_SECRET` in `/opt/hbec/.env`
using the committed guard script. The file remains owner-only (`0600`).

```bash
sudo bash scripts/deploy/ensure-code-runner-secret.sh .env
```

### Long-term Fix
Keep the deployment preflight mandatory and include this required-variable
check in release verification.

## Prevention
- [x] Configuration change applied
- [ ] Monitoring/alerts to add
- [x] Documentation/guard script verified
- [ ] Code changes required

## Related Issues
- None identified.

## References
- `scripts/deploy/ensure-code-runner-secret.sh`
- `docker-compose.production.yml`

---

**Resolved By:** Copilot
**Time to Resolution:** During the 2026-11-07 staging deployment
