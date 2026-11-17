# Heritage PR was stale after its content reached master through another PR

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** GitHub PR #116 review against current `master`; production not exercised
**Severity:** Medium
**Status:** Resolved

## Summary
PR #116 remained open after its four commits had reached `master` through PR #113 as patch-equivalent changes. Its older branch conflicts with later seed-lock and Qdrant reconciliation fixes. Merging it would add no intended heritage content and could undo reviewed safety work during manual conflict resolution.

## Symptoms
- PR #116 showed 31 changed files and no reported checks despite the same content already being on `master`.
- A simulated merge reported conflicts in seed and heritage files.
- The PR description still instructed a direct merge and deploy.

## Environment Details
- **Server/Host:** GitHub `Rest-creator/HBEC`; isolated checkout of master `bc9eabef1`.
- **Services Affected:** Agentic Harness heritage retrieval and deploy-time seeding.
- **Related Components:** `feat/heritage-monuments`, `master`, PR #113, Qdrant, Redis.
- **Time First Observed:** 2026-11-07 after PR #113 merged.

## Investigation Steps

### 1. Initial Diagnosis
Compared PR #116's current head with master and inspected its changed files and release claims.

### 2. Root Cause Analysis
Checked patch equivalence, data file identity, and simulated merge behavior, then ran focused tests on the exact master checkout.

```bash
git cherry -v github/master github/feat/heritage-monuments
git diff --quiet github/master github/feat/heritage-monuments -- AGENTIC_HARNESS/app/shared/data/heritage_corpus.json AGENTIC_HARNESS/app/shared/data/curriculum_maps/zimsec-primary-plusone.json research/semantic/national_monuments research/semantic/plusone_primary
git merge-tree --write-tree github/master github/feat/heritage-monuments
python -m pytest tests/shared/test_heritage_corpus.py tests/shared/test_heritage_monuments.py tests/shared/test_curriculum_maps.py -q
```

### 3. Key Findings
- `git cherry` marked all four PR commits patch-equivalent to master.
- The corpus, primary map data, and research files have no diff against master.
- The merge simulation conflicts with newer seed safety changes.
- All 68 focused tests passed on master; the corpus validates at 143 entries.

## Root Cause
Parallel feature branches carried the same heritage work. PR #113 integrated the content and subsequent fixes, while PR #116 stayed open against the moving master base.

## Prevention / Rule
**Guardrail:** Before merging a parallel PR, check patch equivalence and content identity against current master, then simulate its merge; close a branch whose intended changes are already present and whose conflicts would only reintroduce stale code.

This detects duplicate work even when commit SHAs differ and a three-dot PR diff still appears large.

## Solution

### Immediate Fix
Closed PR #116 with a comment recording the evidence and the remaining staging/production verification. No branch was deleted and no production state changed.

```bash
gh pr close 116 --comment 'Superseded by merged PR #113 ...'
```

### Long-term Fix
Keep feature PRs synchronized with the integration branch, and automatically flag PRs whose commits are patch-equivalent to master before assigning merge review.

## Prevention
- [x] Close the redundant PR without resolving conflicts into master.
- [x] Verify corpus content and focused tests on the exact master checkout.
- [ ] Verify deploy-time seeding and retrieval on the target environment.

## Related Issues
- PR #113 integrated the feature and seed safety fixes.
- PR #116 closed as superseded.
- Existing heritage seed and lock entries in `Database_and_State/` record the distinct code defects and fixes.

## References
- https://github.com/Rest-creator/HBEC/pull/113
- https://github.com/Rest-creator/HBEC/pull/116

---

**Resolved By:** PR #116 closed as superseded
**Time to Resolution:** Same work session
