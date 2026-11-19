# Stacked PR merged into its feature base instead of main

**Date:** 2026-11-19
**Project:** LEC Biotec
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
PR #63 (LEC-092, news & articles) was stacked on PR #62 (LEC-091, product
discovery) and its own description said explicitly: merge #62 first, then
switch #63's base to `main` before merging. Both PRs were merged with a plain
`gh pr merge <n> --merge` without re-targeting #63's base first. GitHub
merged #63 into its stated base, `winston/LEC-091-website-discovery`
(already closed/merged into main via #62) — not into `main`. `main` silently
ended up missing the entire News & Articles feature even though the PR
showed as "Merged" and CI was green.

## Symptoms
- `gh pr view 63 --json state,mergedAt` reported `MERGED`, giving false
  confidence the feature was on `main`.
- After deploying `main` and trying to run the new `manage.py seed_news`
  rollout command, Django reported `Unknown command: 'seed_news'` — and
  `seed_website` too, because the whole #62/#63 diff wasn't actually in the
  local checkout that had been deployed (see also: deploy.sh builds from the
  local working tree, so a stale local `main` deploys stale code even after
  a correct merge upstream — compounded this incident).
- `git log --oneline origin/main` showed the merge commit for #62 but no
  merge commit for #63.

## Environment Details
- **Server/Host:** VPS at 93.127.143.153, `/opt/webapps/lec-biotech`
- **Services Affected:** api (Django management commands), storefront/admin
  (missing News & Articles UI)
- **Related Components:** GitHub stacked-PR workflow, `deploy.sh`
- **Time First Observed:** 2026-11-19, during post-deploy rollout step

## Investigation Steps

### 1. Initial Diagnosis
`manage.py help` on the deployed container listed no `seed_website` or
`seed_news` subcommand, despite both PRs showing merged on GitHub.

### 2. Root Cause Analysis
```bash
gh pr view 63 --json baseRefName,mergeCommit,state,mergedAt
# baseRefName: "winston/LEC-091-website-discovery" (not "main")
git log --oneline origin/main..origin/winston/LEC-091-website-discovery
# showed the #63 merge commit sitting on the feature branch, never landed on main
```

### 3. Key Findings
- `gh pr merge` merges into whatever `baseRefName` is currently set on the
  PR — it does not know or care that the PR's own body says to re-target it
  first.
- A PR's `state: MERGED` only means its diff landed on *some* branch, not
  specifically `main`. It must never be read as "this is live."
- The local working tree used by `deploy.sh` was still on the pre-merge
  commit, so even after fixing the merge target the first redeploy shipped
  stale code — a second, independent failure mode from the same root
  behavior (assuming "merged on GitHub" implies "ready to build").

## Root Cause
Treated `gh pr merge <n> --merge` as sufficient to land a stacked PR on
`main`, without reading and following the PR's own explicit instruction to
re-target its base first. Compounded by never running `git pull`/`git
fetch` + diff check against `origin/main` before invoking a deploy script
that builds from the local working tree.

## Prevention / Rule
**Guardrail:** before merging any PR via `gh pr merge`, run
`gh pr view <n> --json baseRefName` and require it to equal the
repo's declared main branch (from `gh pr view <n> --json baseRepository`
/ the deployment default), aborting with a loud error if a stacked PR's
base still points at a feature branch — and after any merge intended to
reach `main`, verify with `git log --oneline origin/main | grep <sha>`
before treating the feature as live or kicking off a deploy.

This closes the gap because the exact failure was a base-ref mismatch no
one checked for programmatically, and a deploy-before-verify step that
trusted GitHub's "Merged" state instead of the actual contents of `main`.

## Solution

### Immediate Fix
Opened a new PR from `winston/LEC-091-website-discovery` (which carried
#63's already-reviewed merge commit) targeting `main`, waited for CI to go
green, merged it (#64), then `git pull`'d locally before re-running
`deploy.sh` and the `seed_website`/`seed_news --apply` rollout commands.

```bash
gh pr create --head winston/LEC-091-website-discovery --base main ...
gh pr checks 64 --watch
gh pr merge 64 --merge
git pull origin main
./deploy.sh
```

### Long-term Fix
Adopt the guardrail above as a pre-merge check for any PR whose description
mentions being "stacked on" or needing a base-branch switch.

## Prevention
- [ ] Add a `gh pr merge` wrapper/alias that checks `baseRefName` against
      the default branch before merging
- [x] Documented the re-verification step (pull + diff check before deploy)
- [ ] Consider a CI check that fails a stacked PR's base branch if it still
      points at another open/closed feature branch instead of `main`

## Related Issues
- PR #62 (LEC-091), #63 (LEC-092), #64 (corrective re-target of #63 onto
  `main`)

## References
- `winston/LEC-091-website-discovery` branch history
- `docs/decisions/ADR-018-...`, `ADR-019-...` (unaffected by this incident)

---

**Resolved By:** Claude Code (session for tinotendamupezeni@thuthuka.tech)
**Time to Resolution:** ~20 minutes
