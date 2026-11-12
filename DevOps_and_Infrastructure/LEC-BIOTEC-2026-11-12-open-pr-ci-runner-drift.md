# Open PR CI Runner Drift

**Date:** 2026-11-12
**Project:** LEC Biotec
**Environment:** Development / CI
**Severity:** Medium
**Status:** Workaround Applied

## Summary
The current CI workflow is pinned to `ubuntu-24.04` in PR #56, but dependent open PRs #57–#59 still run their historical workflow on `ubuntu-latest`, which resolved to Ubuntu 26.04. Playwright cannot install Chromium on that image, so their E2E jobs fail before tests execute.

## Symptoms
- PRs #57, #58, and #59 report failing E2E jobs.
- Playwright reports: `Playwright does not support chromium on ubuntu26.04-x64`.
- The same dependent PRs also report API mypy failures.

## Environment Details
- **Server/Host:** GitHub Actions hosted runners
- **Services Affected:** CI E2E and API verification jobs
- **Related Components:** `.github/workflows/ci.yml`, Playwright, dependent PR branches
- **Time First Observed:** 2026-11-11

## Investigation Steps

### 1. Initial Diagnosis
Listed all open pull requests, checked their workflow conclusions, and compared the current branch with `origin/main`.

### 2. Root Cause Analysis
The current branch's workflow pins all jobs to `ubuntu-24.04`, while dependent branches were created before that change and retain `runs-on: ubuntu-latest`.

```bash
gh pr checks 57
gh api repos/winstonjthinker/lec-biotech-ascend/actions/jobs/<job-id>/logs
git diff origin/main...HEAD -- .github/workflows/ci.yml
```

### 3. Key Findings
- PR #56 is merge-clean and all four checks pass.
- PRs #57–#59 are open, non-draft, and merge-unstable.
- Their E2E failures occur during browser installation on Ubuntu 26.04.
- Their API failures include real mypy errors in content serializers/views/tests and require separate fixes.

## Root Cause
The open PR stack is not rebased onto the CI runner pin in PR #56. Because each dependent branch carries the older workflow file, GitHub Actions continues resolving `ubuntu-latest` to Ubuntu 26.04 for those branches.

## Prevention / Rule
**Guardrail:** Require every dependent PR in a stacked branch series to rebase or merge the workflow/configuration fix before its checks are treated as representative.

This keeps CI infrastructure changes flowing through the same dependency chain as application changes and prevents stale workflow definitions from masking the state of the intended base.

## Solution

### Immediate Fix
PR #56 pins all CI jobs to `ubuntu-24.04`, the supported runner for the repository's Playwright version.

### Long-term Fix
Merge #56 first, then update/rebase #57–#59 and fix their independent API type errors before merging the stack.

## Prevention
- [x] Configuration change made in PR #56
- [ ] Add an explicit stacked-PR rebase/update procedure
- [ ] Keep CI runner and Playwright upgrades coordinated

## Related Issues
- https://github.com/winstonjthinker/lec-biotech-ascend/pull/56
- https://github.com/winstonjthinker/lec-biotech-ascend/pull/57
- https://github.com/winstonjthinker/lec-biotech-ascend/pull/58
- https://github.com/winstonjthinker/lec-biotech-ascend/pull/59

## References
- `.github/workflows/ci.yml`
- `plan/00-INDEX.md`

---

**Resolved By:** Copilot
**Time to Resolution:** Same-day review
