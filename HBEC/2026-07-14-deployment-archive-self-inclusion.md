# Deployment Archive Included Itself and Blocked the Release

**Date:** 2026-07-14
**Project:** HBEC
**Environment:** CI/CD (staging deployment)
**Severity:** High
**Status:** Investigating

## Summary
The HBEC deployment workflow failed while creating `repo.tar.gz` because the archive command ran in the same directory as the output file and did not safely exclude it. `tar` reported `.: file changed as we read it`, blocking deployment. A later CLI history entry indicates the issue was still occurring while an attempt was made to disable other CI jobs.

## Symptoms
- The Deploy to VPS GitHub Actions job failed during archive creation.
- The command reported: `tar: .: file changed as we read it`.
- Multiple workflows remained active despite an attempted instruction to disable them.

## Environment Details
- **Server/Host:** GitHub Actions runner and HBEC VPS transfer step
- **Services Affected:** Deployment pipeline
- **Related Components:** `.github/workflows/cd.yml`, repository archive step
- **Time First Observed:** 2026-07-14

## Investigation Steps

### 1. Initial Diagnosis
Inspected the failed workflow output and isolated the failure to `tar -czf repo.tar.gz ... .`.

### 2. Root Cause Analysis
The archive output was created inside the directory being archived. Workflow configuration also lacked a verified preflight proving which workflows were active.

### 3. Key Findings
- Archive creation failed before remote deployment could run.
- Workflow state did not match the intended CI configuration state.
- Release preflight must check archive safety and enabled workflow scope.

## Root Cause
The deployment archive was generated inside its own source tree without an isolated output path.

## Solution

### Immediate Fix
Create the archive outside the source tree and validate its contents before transfer.

```bash
tmp_dir=$(mktemp -d)
tar -czf "$tmp_dir/repo.tar.gz" --exclude=.git --exclude=node_modules --exclude=venv .
tar -tzf "$tmp_dir/repo.tar.gz" >/dev/null
```

### Long-term Fix
Make archive creation a version-controlled script with strict error handling and assert the expected workflow files are enabled or disabled before deployment.

## Prevention
- [ ] Build archives outside the directory being archived
- [ ] Exclude generated artifacts and validate archive contents
- [ ] Add a CI preflight for workflow scope and duplicate triggers
- [ ] Fail loudly when workflow state differs from the intended release design

## Related Issues
- `HBEC/2026-08-19-github-actions-billing-blocked-manual-deploy-fallback.md`
- Guide 18: Build Once, Deploy Everywhere
- Guide 19: Issue-to-Verified-Production Engineering Workflow

## References
- Antigravity CLI history, HBEC workspace, 2026-07-14

---

**Resolved By:** Not confirmed in available history
**Time to Resolution:** Unknown
