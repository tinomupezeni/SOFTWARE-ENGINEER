# Production image builds can include untracked source files

**Date:** 2026-10-31
**Project:** HBEC
**Environment:** Production (`hbca-vps`)
**Severity:** Medium
**Status:** Investigating

## Summary
The manual blue/green deployment builds Docker images from `/opt/hbec` after `git reset --hard origin/master`. That reset leaves untracked source files in place. Docker contexts such as `STUDENT/Frontend` then include those files, so an image tagged with a commit SHA can contain source outside that commit.

## Symptoms
- `/opt/hbec` had untracked files under frontend source directories during the 2026-10-31 deployment.
- The deployment script proceeded to build all ten images with a SHA tag.
- An image's SHA tag alone cannot prove its source tree matches the commit.

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** Blue/green Docker image builds, particularly source contexts with untracked files.
- **Related Components:** `scripts/deploy/manual-deploy-color.sh`, Dockerfiles, `.dockerignore` files.
- **Time First Observed:** 2026-10-31 topic hierarchy deployment.

## Investigation Steps

### 1. Initial Diagnosis
The explicit-ref deployment stopped because the backup script was locally modified. The default deployment then reset tracked files and continued.

### 2. Root Cause Analysis
`git reset --hard` does not remove untracked files. The deployment script runs `docker build` against the same checkout, and `STUDENT/Frontend/.dockerignore` excludes dependencies and build output but not untracked source files.

```bash
ssh hbca-vps 'cd /opt/hbec && git status --short'
rg -n 'git reset --hard|docker build' scripts/deploy/manual-deploy-color.sh
cat STUDENT/Frontend/.dockerignore
```

### 3. Key Findings
- Untracked files existed under `STUDENT/Frontend/src/` and `ADMIN/adminFrontend/src/`.
- The admin backend context for the topic repair had no untracked files.
- No public cutover had occurred when this was found.

## Root Cause
The deployment assumes a hard reset yields a clean build context, but Git retains untracked files and Docker includes them unless `.dockerignore` excludes them.

## Prevention / Rule
**Guardrail:** Before building a SHA-tagged image, fail the deployment if `git ls-files --others --exclude-standard` finds a file inside any Docker build context, or build every image from a clean archive of the target commit.

This makes the image's source match the commit named by its tag.

## Solution

### Immediate Fix
The topic repair's admin backend context was checked for untracked files. The broader deployment source-cleanliness issue remains open.

```bash
ssh hbca-vps 'cd /opt/hbec && git status --short ADMIN/adminBackend'
```

### Long-term Fix
Build from isolated clean Git worktrees or archives, while injecting deployment configuration separately from source contexts.

## Prevention
- [ ] Add a build-context cleanliness gate or clean archive build.
- [ ] Verify every tagged image's source provenance at deployment.

## Related Issues
- `Backend_and_API/HBEC-2026-10-31-topic-sharing-flattened-hierarchy.md`

## References
- `scripts/deploy/manual-deploy-color.sh`
- `STUDENT/Frontend/.dockerignore`

---

**Resolved By:** Pending
**Time to Resolution:** Ongoing
