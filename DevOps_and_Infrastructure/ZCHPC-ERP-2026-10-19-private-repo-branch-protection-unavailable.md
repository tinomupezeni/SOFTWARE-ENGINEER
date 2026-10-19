# Branch Protection Unavailable on Current GitHub Plan

**Date:** 2026-10-19
**Project:** ZCHPC ERP
**Environment:** Remote GitHub repository
**Severity:** High
**Status:** Investigating

## Summary
Server-side branch protection cannot currently be enabled for
`tinomupezeni/ZCHPC-ERP` because the repository is private and the active
GitHub plan does not include branch protection or repository rulesets. The
requested `staging` branch also does not exist on the remote repository.

## Symptoms
- The remote repository is private.
- `staging` is not present in the remote branch list.
- GitHub's branch-protection API returns HTTP 403:
  `Upgrade to GitHub Pro or make this repository public to enable this feature.`
- GitHub's repository-rulesets API returns the same plan restriction.

## Environment Details
- **Server/Host:** GitHub
- **Services Affected:** Repository governance and staging promotion workflow
- **Related Components:** `tinomupezeni/ZCHPC-ERP`, intended `staging` branch
- **Time First Observed:** 2026-10-19

## Investigation Steps

### 1. Initial Diagnosis
Queried repository metadata, remote branches, branch protection, repository
rulesets, and collaborator permissions using the GitHub CLI.

### 2. Root Cause Analysis
```bash
gh repo view tinomupezeni/ZCHPC-ERP \
  --json nameWithOwner,defaultBranchRef,isPrivate,viewerPermission,visibility
gh api repos/tinomupezeni/ZCHPC-ERP/branches/staging
gh api repos/tinomupezeni/ZCHPC-ERP/branches/staging/protection
gh api repos/tinomupezeni/ZCHPC-ERP/rulesets
```

### 3. Key Findings
- `default_branch` is `main`; the repository is private.
- The remote branch list contains no `staging` branch.
- Branch protection and rulesets are rejected by GitHub at the plan level,
  before any rule can be created.
- Repository collaborators currently have push permission, so without a
  protected branch they can push to any existing branch they can target.

## Root Cause
The repository's current GitHub plan does not expose server-side branch
protection for private repositories. This is a GitHub billing/feature
availability constraint, not an invalid protection payload or local CLI issue.

## Prevention / Rule
**Guardrail:** Require a GitHub plan capability check in the release-governance
setup procedure before creating protected environment branches.

This prevents substituting a client-side convention or a post-push workflow for
actual server-side authorization controls that Git can bypass.

## Solution

### Immediate Fix
No fake protection workflow was added. Such a workflow would run after a push
and would not reliably prevent unauthorized pushes or branch deletion.

### Long-term Fix
Upgrade the account/repository to a GitHub plan that supports branch
protection for private repositories, then create `staging` and apply a rule
requiring pull requests, preventing force-pushes and deletion, and restricting
administrative bypass as far as the plan supports.

## Prevention
- [ ] Enable GitHub Pro/Team/Enterprise capability for the private repository
- [ ] Create the remote `staging` branch from the intended baseline
- [ ] Apply branch protection before granting staging write access
- [ ] Use pull-request reviews and required CI checks for staging promotion

## Related Issues
- None identified.

## References
- `gh api repos/tinomupezeni/ZCHPC-ERP/branches/staging/protection` → HTTP 403
- `gh api repos/tinomupezeni/ZCHPC-ERP/rulesets` → HTTP 403
- `gh api repos/tinomupezeni/ZCHPC-ERP/branches` → no `staging` branch

---

**Resolved By:** Unassigned
**Time to Resolution:** Blocked by GitHub plan capability
