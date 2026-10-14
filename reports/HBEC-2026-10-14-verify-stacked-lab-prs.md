# Verified Stacked Interactive Learning PRs

**Date:** 2026-10-14
**Project:** HBEC
**Type:** Merge Verification / Code Review
**Status:** Completed

## Summary

PR #95, “Float or sink: density,” and PR #96, “Moments: balance the metre
rule,” are already present in the local `master` branch and
`origin/master`, in the required stacked order. No duplicate merge was
performed. The changes were validated against the global Code Review guide
and focused backend, frontend, typecheck, and visual-model checks.

## Context / Trigger

The requested action was to pull and merge PRs #95 and #96 into the local
codebase, with #96 merged after #95. GitHub still reports both pull requests
as open because their bases are the split branches
`split/lab-liquid-pressure` and `split/lab-float-sink`, respectively.

## Scope

Included:

- Git ancestry and branch state for PRs #95 and #96
- Focused Harness tests for density and balance-point behavior
- Focused Student Frontend tests for both interactives and workbench models
- Student Frontend TypeScript validation
- Axon family/model checks

Excluded:

- Re-merging commits already contained in `master`
- Changes to application code
- Closing the GitHub pull requests
- Fixing unrelated pre-existing visual catalog warnings

## Method

The global `SOFTWARE-ENGINEER` Code Review guide was read before verification.
The remote refs were fetched, PR metadata was inspected with `gh`, merge commit
parents and ancestry were checked with Git, and focused tests were run for the
affected surfaces.

## Decisions & Findings

- PR #95's head `7bd93378` is an ancestor of `master`.
- PR #96's head `e2696e70` is an ancestor of `master`.
- The merge order is correct:
  - `0a92553f` merges PR #95.
  - `bda1954a` merges PR #96 on top of #95.
- Local `master` and `origin/master` were equal after fetching.
- GitHub's open PR state reflects the stacked split-branch bases, not missing
  code in `master`.
- The Axon check reports four existing “blurb too thin” warnings for
  `animal-cell` and `solar-system`; these are unrelated to the two PRs.

## Changes Made

No HBEC source changes were made. The requested changes were already present.

## Verification

- Harness focused suite: **99 passed**
- Student Frontend focused suite: **28 passed**
- Student Frontend typecheck: **passed**
- Axon family contracts: **passed**
- Axon model check: reached the known four pre-existing warnings
- Worktree changes unrelated to the PRs were preserved

## Follow-ups / Deferred

- The PRs may be closed on GitHub if they are no longer needed as tracking
  records, but that was not performed because the request was to update the
  local codebase.
- The four pre-existing Axon blurb warnings remain outside this verification
  scope.

## References

- HBEC PR #95
- HBEC PR #96
- `SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/24. Code Review.md`
- Merge commit `0a92553f`
- Merge commit `bda1954a`

---

**Completed By:** Copilot
**Duration:** One session
