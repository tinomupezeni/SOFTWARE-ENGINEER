# Initial promotion merge omitted the complete staging tip

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Release preparation
**Severity:** High
**Status:** Resolved

## Summary
An interrupted backend merge left the index populated from `origin/staging` at `fe92781` rather than the local staging tip `ca7843e`. The resulting local merge commit initially omitted the observability and deployment changes. The mistake was detected before any push or deployment, corrected by merging the actual staging tip, and verified in the final tree.

## Symptoms
- The first promotion commit had `fe92781` as its staging parent instead of `ca7843e`.
- `observability/` was absent from that intermediate commit.
- The release had not yet been pushed or deployed when detected.

## Environment Details
- **Server/Host:** Local release workstation
- **Services Affected:** Backend release promotion
- **Related Components:** Backend Git merge index, `main`, `staging`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Compared the merge commit parents and tree against the intended local staging branch.

### 2. Root Cause Analysis
The first merge command stopped because the index already contained an interrupted merge. After conflict cleanup, the staged index was committed without re-running the merge against the local `staging` ref.

```bash
git show -s --format='%H %P %s' HEAD
git rev-parse staging
git ls-tree -r --name-only HEAD
```

### 3. Key Findings
- Intermediate merge parent: `fe92781`.
- Intended staging tip: `ca7843e`.
- Corrected merge commit: `657148b`.
- No remote branch or VPS state was changed by the intermediate commit.

## Root Cause
The release workflow treated a partially merged index as if it represented the requested source branch instead of validating the merge parent and resulting tree before commit.

## Prevention / Rule
**Guardrail:** Before pushing a promotion merge, require an automated assertion that the merge commit has the exact intended source tip as a parent and that required release paths (including `observability/` and deployment assets) exist in the committed tree.

This catches stale interrupted-index state before a branch push or production build can consume it.

## Solution

### Immediate Fix
Merged the actual local `staging` tip into backend `main`, verified observability files and deployment assets, then ran backend checks and tests.

### Long-term Fix
Add source-commit and required-path assertions to the deployment preflight and replace mutable `latest` artifact selection with immutable release identity.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- `ProjectFlow-2026-10-15-source-rollback-risk.md`
- `ProjectFlow-2026-10-15-frontend-source-drift-regression.md`

## References
- Backend commits `657148b`, `31e3d5c`
- Backend `staging` tip `ca7843e`
- `projectflow_backend/deploy.sh`

---

**Resolved By:** Copilot
**Time to Resolution:** Same release session
