# Deployment source is behind the running production feature set

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production
**Severity:** Critical
**Status:** Investigating

## Summary
The checkout used by the local deployment script is on `main` at commit `9f63b22`, while the running production image contains application modules and migrations that are absent from that checkout. The image includes `helpcenter`, `finance`, `integrations`, and `vault`, plus later migration history. Running the local `deploy.sh` from the current checkout would build and replace production with an older feature set.

## Symptoms
- The running backend image contains modules not present in the local `main` checkout.
- The local repository's `origin/staging` branch contains newer feature commits than local `main`.
- The deployment script builds from the current working tree without checking branch, commit, or feature parity.

## Environment Details
- **Server/Host:** `restk-vps`
- **Services Affected:** ProjectFlow backend and database schema
- **Related Components:** `deploy.sh`, local Git branches, running `projectflow-backend:latest`
- **Time First Observed:** 2026-10-15 during pre-deployment inspection

## Investigation Steps

### 1. Initial Diagnosis
Compared local Git history and tree contents with the running container's application modules and migration files.

### 2. Root Cause Analysis
The deployment script accepts any current checkout and uses mutable `latest` image tags. There is no preflight check that the checkout contains the production feature set or that the image source commit is recorded.

```bash
git branch -a -vv
docker exec projectflow-backend-1 find /app -maxdepth 2 -type d
docker exec projectflow-backend-1 find /app -maxdepth 3 -type f -name '000*.py'
```

### 3. Key Findings
- Local `main`: `9f63b22`.
- Local `origin/main`: `e4dad21`.
- Local `origin/staging`: `4eb34be` before the fetch update, with newer staging commits available remotely.
- Running image contains `/app/helpcenter`, `/app/finance`, `/app/integrations`, and `/app/vault`.
- Local `main` has no corresponding application directories.

## Root Cause
Production source lineage is not enforced by the deployment process, and mutable image tags obscure which source revision is being promoted.

## Prevention / Rule
**Guardrail:** Require the deploy script to reject a dirty tree and non-approved branch, build images tagged with the exact Git commit, and verify the image's embedded commit matches the deployment manifest before any container replacement.

This prevents an older or incomplete checkout from silently replacing a newer production feature set.

## Solution

### Immediate Fix
Deployment was not run. No VPS services were modified.

### Long-term Fix
- Identify and checkout the intended production source branch/commit.
- Preserve the current image digests and database volume as rollback references.
- Add commit metadata to images and immutable tags.
- Add a preflight feature/schema compatibility check.
- Replace `docker compose down` with a controlled recreate after validation.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-deployment-drift-and-host-mismatch.md`
- `ProjectFlow-2026-10-15-production-config-hardening.md`

## References
- Local repository Git history and branches
- Running container `projectflow-backend-1`
- Local `deploy.sh`

---

**Resolved By:** Unassigned
**Time to Resolution:** Ongoing
