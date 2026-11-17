# Main bookkeeping PR was ahead of production and described a stale delta

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** GitHub PR #114 and read-only production release markers
**Severity:** High
**Status:** Workaround Applied

## Summary
PR #114 proposed moving `main` to the latest `master` as a production release record. Its description said 17 commits, but the branch delta was 96 commits and 934 files. The PR head was `bc9eabef1c612030293ab0a7fab0d04a22aaeb3d`, while the production active-color marker reported blue at `7b8b38a`. The owner then requested the code synchronization before staging. The PR was relabeled as deployment-pending and merged at `03a58d858136edfc0cd82ae7ac89dd3fe3154721`; `main` must not be used as a live-release marker for this interval.

## Symptoms
- PR title and body described an obsolete 17-commit snapshot.
- The current PR head does not match the active production release marker.
- No status checks are reported on PR #114, so mergeability alone does not prove release state.

## Environment Details
- **Server/Host:** GitHub `Rest-creator/HBEC` and `/opt/hbec` on `hbca-vps` (read-only marker check).
- **Services Affected:** Release bookkeeping, blue/green deployment workflow.
- **Related Components:** `main`, `master`, `.github/workflows/cd.yml`, `active_color`, `.sha_blue`, `.sha_green`.
- **Time First Observed:** 2026-11-07, after PR #113 merged to `master`.

## Investigation Steps

### 1. Initial Diagnosis
Read PR #114's title/body and checked its current head, base, mergeability, and reported checks.

### 2. Root Cause Analysis
Compared branch ancestry and read the production release markers without changing the VPS.

```bash
git rev-list --left-right --count github/main...github/master  # 0 96
git diff --name-only github/main...github/master | wc -l       # 934
ssh hbca-vps 'cd /opt/hbec && cat active_color .sha_blue .sha_green'
```

### 3. Key Findings
- `main` has no unique commits; it is a strict ancestor of `master`.
- PR #114 is a large, moving release delta, not the static 17-commit change described earlier.
- Production's active marker reports a different SHA from the PR head. The marker alone is not full runtime artifact proof.

## Root Cause
The PR description captured a historical branch snapshot, while its head tracks the moving `master` branch. No merge gate tied the `main` bookkeeping update to a verified production cutover of the exact head SHA.

## Prevention / Rule
**Guardrail:** A release record must either match the verified active production artifact or explicitly state that it is only a code synchronization and name the deployment-pending SHA.

This prevents a Git branch update from being mistaken for a deployed release. A future automated release-state check can enforce SHA equality using the active deployment's image labels, not only marker files.

## Solution

### Immediate Fix
Updated PR #114's title and body with the current 96-commit snapshot and production marker mismatch; initially converted it to draft. After the owner's explicit request to merge ahead of staging, changed the title/body to say code synchronization and deployment pending, marked it ready, and merged it. No production state changed.

```bash
gh api --method PATCH repos/Rest-creator/HBEC/pulls/114 --input /tmp/hbec-pr114-patch.json
gh pr ready 114 --undo
gh pr ready 114
gh pr merge 114 --merge --match-head-commit bc9eabef1c612030293ab0a7fab0d04a22aaeb3d
```

### Long-term Fix
Add an automated check that compares the PR head with the actual active deployment artifact after cutover, then makes the bookkeeping PR eligible for merge only at that verified SHA.

## Prevention
- [ ] Verify exact running image revisions and migration state after cutover.
- [ ] Verify authenticated learner, admin Claude, code-runner, and exam-paper seed user paths.
- [ ] Recheck `master` head and refresh the PR snapshot immediately before merge.
- [ ] Add an automated production-SHA promotion check.

## Related Issues
- PR #113: merged with automatic deployment skipped for the planned staging step.
- PR #114: merged as code synchronization, deployment pending.

## References
- GitHub PR #114: https://github.com/Rest-creator/HBEC/pull/114
- HBEC `docs/DEPLOYMENT.md` blue/green release procedure.

---

**Resolved By:** Release record wording corrected; production verification pending
**Time to Resolution:** Ongoing
