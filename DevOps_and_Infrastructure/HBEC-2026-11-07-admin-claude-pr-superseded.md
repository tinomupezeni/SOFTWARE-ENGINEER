# Admin Claude PR remained open after its code was already merged

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** GitHub PR #115 review against current `master`; production not exercised
**Severity:** Medium
**Status:** Resolved

## Summary
PR #115 remained open after the same admin Claude implementation was integrated through PR #113. Its description also instructed use of a GitHub Actions secret and claimed no VPS `.env` edit, while the owner now plans to put `ANTHROPIC_API_KEY` directly in the VPS `.env` before staging. Merging #115 would add a redundant merge commit and preserve misleading release instructions.

## Symptoms
- PR #115 was open with 9 changed files and no reported checks.
- Its code changes appeared to be new in the three-dot PR diff, but were already in `master` through another history path.
- Its secret instructions disagreed with the current deployment plan.

## Environment Details
- **Server/Host:** GitHub `Rest-creator/HBEC`.
- **Services Affected:** Agentic Harness admin Claude paper generation and content upload.
- **Related Components:** `master`, `feat/admin-claude`, PR #113, PR #115, VPS `.env`.
- **Time First Observed:** 2026-11-07 after PR #113 merged.

## Investigation Steps

### 1. Initial Diagnosis
Read PR #115's current head, base, changed files, and setup instructions after merging PR #114.

### 2. Root Cause Analysis
Simulated a merge of `feat/admin-claude` into current `master` and compared the resulting tree with `master`.

```bash
git merge-tree --write-tree github/master github/feat/admin-claude
git rev-parse github/master^{tree}
```

### 3. Key Findings
- Both commands returned tree `0e1e4b76998ba1abaca53a2fc3701ad1e53fa2e7`.
- The simulated merge would change no tracked file.
- The original PR description's repository-secret path is obsolete for the planned staging deployment.

## Root Cause
The same feature was developed on two branches and one copy entered `master` through PR #113, while PR #115 stayed open. The PR description was not reconciled with the owner's later secret-provisioning decision.

## Prevention / Rule
**Guardrail:** Before merging a parallel feature PR, compare the simulated merge result tree to the current base tree; if they match, close the redundant PR and record the winning integration path.

This catches equivalent code carried by different commits, which commit ancestry and three-dot PR diffs alone can miss.

## Solution

### Immediate Fix
Closed PR #115 with a comment citing PR #113 and the identical merge tree, and recorded that the VPS `.env` key setup remains a staging prerequisite. No branch was deleted and no production change was made.

```bash
gh pr close 115 --comment 'Superseded by PR #113 ...'
```

### Long-term Fix
Keep one active PR per feature or automatically detect tree-equivalent PRs after a parallel branch merges. Refresh deployment instructions when the secret source changes.

## Prevention
- [x] Close the redundant PR without adding a no-op merge commit.
- [x] Record the current VPS key plan in the closing comment.
- [ ] Verify `admin/claude` registration and admin-only routing in staging.

## Related Issues
- PR #113 merged the implementation.
- PR #115 closed as superseded.
- `HBEC-2026-11-07-admin-claude-deploy-secret-absent.md` records the missing key and staging prerequisite.

## References
- https://github.com/Rest-creator/HBEC/pull/113
- https://github.com/Rest-creator/HBEC/pull/115

---

**Resolved By:** PR #115 closed as superseded
**Time to Resolution:** Same work session
