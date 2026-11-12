# Open PR Status Review

**Date:** 2026-11-12
**Project:** LEC Biotec
**Type:** Audit
**Status:** Completed

## Summary
Reviewed the LEC Biotec monorepo and its GitHub pull-request state. The repository is a Vite/React storefront and admin application with a Django/DRF API in an npm-workspaces monorepo. Sixteen pull requests are open; the stack is largely linear, with PR #56 independently targeting `main` and PRs #57–#59 depending on the preceding design/content branches.

## Context / Trigger
The user requested a codebase read and a check of open pull requests from Git.

## Scope
Included repository structure, current branch state, recent commits, open PR metadata, dependency bases, changed-file scope for the newest PRs, CI conclusions, and failed-job logs. Excluded code changes, local test execution, and detailed review of every historical PR.

## Method
Inspected `plan/00-INDEX.md`, `package.json`, Git branches/status/history, GitHub open-PR metadata, PR diffs, check results, and failed GitHub Actions logs. Applied the repository's E2E/CI guidance when interpreting Playwright and workflow failures.

## Decisions & Findings
- The current checkout is `winston/LEC-087-pin-ci-runner`, clean, one commit ahead of `origin/main`, and backs PR #56.
- PR #56 is open, non-draft, merge-clean, and all listed checks pass.
- PRs #57–#59 are open and non-draft but merge-unstable.
- Their E2E jobs fail before tests because the branches still use `ubuntu-latest`, which resolves to Ubuntu 26.04 and is unsupported by the repository's Playwright Chromium installation.
- Their API jobs also fail mypy. #57 reports a `LogoSerializer` keyword/type issue and unindexable test values; #58 and #59 additionally report a `SiteTextRowSerializer` argument mismatch.
- The frontend verification job passes on #57–#59, so the failures are concentrated in runner compatibility and API typing.

## Changes Made
No changes were made to the LEC Biotec repository. This review created the accompanying engineering issue log for the CI runner drift and this report.

## Verification
- `git status --short --branch`
- `git log -5 --oneline --decorate`
- `gh pr list --state open`
- `gh pr view` / `gh pr checks` for PRs #56–#59
- GitHub Actions job-log inspection for the failed API and E2E jobs

## Follow-ups / Deferred
Merge PR #56 first, then rebase or merge its CI workflow into the dependent stack. Fix the independently reported API mypy errors, rerun all checks, and review the full stack before merging.

## References
- `plan/00-INDEX.md`
- `package.json`
- `.github/workflows/ci.yml`
- `LEC-BIOTEC-2026-11-12-open-pr-ci-runner-drift.md`
- PRs #44–#59 in `winstonjthinker/lec-biotech-ascend`

---

**Completed By:** Copilot
**Duration:** Same-day review
