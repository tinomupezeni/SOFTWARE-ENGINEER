# Production Deployment Drift: hbca-vps Behind GitHub

**Date:** 2026-11-07
**Project:** LEC Virtual Labs
**Environment:** Production (`hbca-vps`)
**Severity:** High
**Status:** Investigating

## Summary

The GitHub repository is synchronized at commit `4b2cb34`, but the production
checkout and live green containers on `hbca-vps` remain at older commit
`821903a`. The application is healthy and publicly reachable, but production
does not contain the current repository state.

## Symptoms

- Production green containers run `vlabs-backend:sha-821903a` and
  `vlabs-frontend:sha-821903a`.
- The VPS checkout at `/sdb-disk/projects/vlabs` is clean but remains at
  `821903aa92580f934b0de805b2167e3e6f205cee`.
- GitHub `main`, `production`, and `experimental` all point to
  `4b2cb34b22b807ea55470c166e945e72e41b0a2d`.
- A direct `docker compose ... ps` invocation without the deploy script's
  exported tag variables fails because `TAG_GREEN` is unset.

## Environment Details

- **Server/Host:** `hbca-vps` (`/sdb-disk/projects/vlabs`)
- **Services Affected:** VLabs production app tier; shared `hbec-gateway`
  routing
- **Related Components:** `scripts/deploy/deploy-color.sh`,
  `scripts/deploy/cutover.sh`, `docker-compose.production.yml`
- **Time First Observed:** 2026-11-07 during deployment-state verification

## Investigation Steps

### 1. Initial Diagnosis

Compared local Git state, GitHub branches and pull requests, the VPS checkout,
deployment markers, container image tags, gateway routing, migrations, and
public endpoints.

### 2. Root Cause Analysis

```bash
git status --porcelain=v1 --branch
git ls-remote --heads origin
ssh hbca-vps 'cd /sdb-disk/projects/vlabs && git rev-parse HEAD && git ls-remote origin refs/heads/main'
ssh hbca-vps 'docker ps --format "{{.Names}} {{.Image}} {{.Status}}"'
```

### 3. Key Findings

- The VPS checkout and live green color are both pinned to `821903a`.
- `active_color` is `green`; Caddy routes both `/vlabs` and `/labs/*` to
  `vlabs-frontend-green`.
- Blue is also healthy but is only `sha-0aec105`.
- PostgreSQL and all blue/green app containers report healthy.
- The public app returns HTTP 200, the authenticated API correctly returns
  HTTP 401 without credentials, and the bridge asset returns HTTP 200.
- The active container reports all inspected migrations applied.

## Root Cause

The manual VPS deployment was not rerun after GitHub advanced from the
`821903a` release to `4b2cb34`; there is no automated promotion or artifact
identity gate enforcing checkout parity before cutover.

## Prevention / Rule

**Guardrail:** Make the VPS deploy preflight fetch the target branch and fail
unless the checkout SHA, built image revision labels, and intended GitHub SHA
are identical before any cutover is allowed.

This prevents a healthy but stale blue/green color from being treated as the
current release and makes artifact identity an explicit release gate.

## Solution

### Immediate Fix

No production change was made during this audit. The current live color was
left untouched because promotion requires an explicit deployment decision.

### Long-term Fix

Add a checked, non-interactive preflight or CI-driven promotion step that
records the source SHA and verifies the running image labels after cutover.

## Prevention

- [ ] Deploy the intended current commit after owner approval.
- [ ] Add checkout/image SHA parity validation to the deployment gate.
- [ ] Make Compose inspection use the same tag-loading path as deployment.
- [ ] Record the deployed SHA and migration result for each cutover.

## Related Issues

- None identified during this audit.

## References

- `intelligent_memory_management/architecture/deploy-runbook.md`
- `intelligent_memory_management/decisions/ADR-004-vps-bluegreen-deployment.md`
- `scripts/deploy/deploy-color.sh`
- `scripts/deploy/cutover.sh`

---

**Resolved By:** Pending deployment owner decision
**Time to Resolution:** Open
