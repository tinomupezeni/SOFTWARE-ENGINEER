# Frontend deployment used a stale source line

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The frontend portion of the deployment used the local `projectflow-hq` checkout without validating its branch or commit. At deployment time, that checkout was on frontend `main` at `ea5abdd`, while frontend `origin/staging` had newer UI commits through `7c1aea4`. The deployment therefore replaced the newer frontend with an older source line, independently of the localhost API/CORS regression.

## Symptoms
- The deployed frontend appeared to regress to an older UI version.
- The prior working image was a static nginx image created on 2026-10-14.
- The replacement was built from a local checkout whose source revision was not recorded in the image.

## Environment Details
- **Server/Host:** `restk-vps`
- **Services Affected:** ProjectFlow frontend
- **Related Components:** `projectflow-hq` Git branches, `deploy.sh`, frontend Docker image
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Compared the frontend repository branches and commits with the previous deployed image and deployment script behavior.

### 2. Root Cause Analysis
The backend deployment script builds `../projectflow-hq` directly from whatever working tree happens to be present. It does not fetch, select, or verify the frontend release branch, and it does not embed the frontend source commit in the image.

```bash
git branch -a -vv
docker image inspect projectflow-frontend:latest
docker history --no-trunc <previous-frontend-image>
```

### 3. Key Findings
- Frontend local `main` at deployment: `ea5abdd`.
- Frontend remote `origin/staging`: `7c1aea4` with newer UI commits.
- Previous working image: `sha256:e8c6707813691896636530a74a84fced5337effe9fd82459ce4cfc34f10ef341`.
- Previous image was a static nginx build; the replacement used the local frontend Dockerfile and Vite development server.
- No source commit metadata was embedded in the frontend image.

## Root Cause
The deployment process coordinated the backend staging branch but treated the frontend as an unmanaged adjacent working directory.

## Prevention / Rule
**Guardrail:** Require the deployment to accept and verify an explicit frontend commit/branch, build from a clean checkout of that revision, and embed the revision in the image labels.

This prevents a backend staging deployment from silently pairing with stale or unrelated frontend source.

## Solution

### Immediate Fix
Rolled back the frontend container to the previous known-good image. Backend and database were not rolled back.

### Long-term Fix
- Make frontend staging revision selection explicit in `deploy.sh`.
- Fetch and verify the frontend revision before building.
- Use a production static-serving Dockerfile.
- Add frontend image source labels and a UI/API smoke test.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-frontend-api-loopback-regression.md`
- `ProjectFlow-2026-10-15-source-rollback-risk.md`

## References
- `projectflow-hq` frontend Git history
- `projectflow_backend/deploy.sh`
- Previous frontend image `sha256:e8c67078...`

---

**Resolved By:** Unassigned
**Time to Resolution:** Ongoing
