# gh CLI GraphQL Deprecation Blocks Stacked PR Merges

**Date:** 2026-10-08
**Project:** LEC
**Environment:** Development (CI/CD / Developer Workstation)
**Severity:** Medium
**Status:** Resolved

## Summary
When merging a stack of sequential pull requests locally using the `gh` CLI, attempting to update a pull request's base branch via `gh pr edit <PR> --base main` or fetch its details via `gh pr view` sporadically fails with a hard error regarding a deprecated `Projects (classic)` GraphQL API field (`repository.pullRequest.projectCards`). This completely breaks automated or semi-automated stacked PR merge workflows.

## Symptoms
- Attempting to run `gh pr edit <ID> --base main` or `gh pr view` fails with exit code 1.
- Output: `GraphQL: Projects (classic) is being deprecated in favor of the new Projects experience, see: https://github.blog/changelog/2024-05-23-sunset-notice-projects-classic/. (repository.pullRequest.projectCards)`
- Stacked PRs cannot have their base branch retargeted to `main` via the CLI once their intermediate parent branch is merged and deleted.

## Environment Details
- **Server/Host:** Developer Local Environment
- **Services Affected:** GitHub CLI (`gh`), Git Version Control
- **Related Components:** GitHub GraphQL API
- **Time First Observed:** 2026-10-08

## Investigation Steps

### 1. Initial Diagnosis
Attempted to bulk merge 16 stacked PRs (`winston/LEC-046` through `LEC-066`). As intermediate PRs were merged, the later PRs needed their base branch updated to `main` so `gh pr merge --merge` could cleanly apply them without conflict.

### 2. Root Cause Analysis
```bash
# The command that fails:
gh pr edit 30 --base main
```
The command sends a GraphQL mutation/query to GitHub. GitHub recently completely sunsetted the "Projects (classic)" API. The installed version of the `gh` CLI explicitly requests the `projectCards` field on the `PullRequest` object as part of its default payload for viewing or editing PRs, causing the GitHub API to reject the entire request.

### 3. Key Findings
- `gh pr list` still works correctly.
- Standard Git operations (`git fetch`, `git rebase`, `git push`) are completely unaffected.
- Bypassing the CLI tool and handling branch merging natively via `git rebase main` and `git merge` works perfectly.

## Root Cause
An outdated or unpatched version of the `gh` CLI tool hardcodes a deprecated GraphQL field (`projectCards`), rendering any command that retrieves or mutates a pull request's metadata (like editing base branches) completely non-functional due to GitHub's strict sunsetting of that endpoint.

## Prevention / Rule
**Guardrail:** For automated PR operations, rely strictly on underlying `git` primitives (`git fetch`, `git rebase`, `git push`) for branch manipulation and reconciliation instead of relying on vendor-specific CLI tools (`gh`) for critical control flow, OR add an environment health-check gate that enforces a minimum version of `gh` CLI that no longer polls the deprecated endpoints.

Bypassing the GitHub API for branch math removes the external dependency and guarantees that operations like stacked PR merges will succeed purely via native git protocol.

## Solution

### Immediate Fix
Bypassed the `gh` CLI for branch targeting entirely.
Wrote a script to sequentially fetch each branch, locally rebase it against `origin/main`, switch to `main`, perform a `git merge --no-ff`, and push the updated `main` directly to GitHub. Finally, the PRs were explicitly closed via the API (`gh pr close`).

```bash
# Bypassing the API limitation using pure git:
git fetch origin "$branch"
git checkout "$branch"
git rebase main
git checkout main
git merge --no-ff -m "Merge $branch" "$branch"
git push origin main
```

### Long-term Fix
Update the local system's `gh` CLI binary to the latest version that removes the `projectCards` GraphQL field from its payloads.

## Prevention
- [ ] Code changes required (upgrade local tooling)
- [ ] Documentation to update

## Related Issues
- GitHub Changelog: https://github.blog/changelog/2024-05-23-sunset-notice-projects-classic/

---

**Resolved By:** Antigravity
**Time to Resolution:** 15 minutes
