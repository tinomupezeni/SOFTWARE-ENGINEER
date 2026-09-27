# `.env` is tracked in git and not ignored, so the next secret added to it is committed

**Date:** 2026-09-27
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** High
**Status:** Open — no secret currently exposed, pattern is the defect

## Summary
`.env` is tracked in the repository and does not appear in `.gitignore`. It currently holds
six Supabase values, all of which are publishable/anon keys of the kind designed to be
public — a client-side Vite app cannot keep such a key secret, so nothing is presently
exposed. The defect is the pattern, not the current contents: the file is a committed secret
carrier with no guard, and the overwhelmingly common failure mode for this is a
`SUPABASE_SERVICE_ROLE_KEY` or similar being added later and swept into a commit by
`git add -A`, which is a single command away and is explicitly the thing the project's own
commit process warns about.

## Symptoms
- `git ls-files .env` resolves: the file is in the index.
- `git check-ignore .env` finds nothing: `.gitignore` has no `.env` rule. It does have
  `*.local` and `.dev.vars`, so the project considered env files and covered two of the
  conventions while missing the most common one.
- Any future secret written to `.env` is committed by default.

## Environment Details
- **Server/Host:** local dev; repo `pixel-perfect-replication` on `main`
- **Services Affected:** repository hygiene; future Supabase and any other credentials
- **Related Components:** `.env`, `.gitignore`, `package.json` (`api:types` and Supabase
  integration files)
- **Time First Observed:** 2026-09-27, while running a secret scan before committing

## Investigation Steps

### 1. Initial Diagnosis
`WORKING-PROCESS.md` requires reviewing the actual diff before staging and never using
`git add -A` blindly, specifically to avoid committing something that looks innocuous but
carries a secret. Checking what `git add -A` would have swept in.

### 2. Root Cause Analysis
```bash
git ls-files --error-unmatch .env   # -> .env          (tracked)
git check-ignore -v .env            # -> (no match)    (not ignored)
grep -nE 'env|\.local|dev\.vars' .gitignore
# -> node_modules, dist, *.local, .dev.vars
```
The file was committed before `.gitignore` covered it, and tracking is sticky: adding an ignore
rule does not untrack an already-tracked path.

Value inspection was deliberately done without printing values (length and shape only), to
confirm the exposure assessment without leaking into a transcript or a log.

### 3. Key Findings
- All six values are Supabase *publishable* keys and a project URL. The `VITE_`-prefixed
  variants are inlined into the client bundle by design, so they are public by construction.
  There is no service-role key in the file.
- The committed copy is identical to the working copy, so nothing has been edited since it was
  committed and there is no history of a rotated secret in it.
- `.gitignore` covers `*.local` and `.dev.vars` but not `.env`, which suggests the gap is an
  oversight rather than a deliberate decision to commit env files.

## Root Cause
`.env` was committed before the ignore rules were written, and the standard fix — adding an
ignore rule — does not affect already-tracked files. So the repository is in the worst state to
be in: the file is both tracked *and* unignored, which means it is neither protected nor
obviously wrong to a reader, and the protection everyone assumes `.env` provides is absent.

## Prevention / Rule
**Guardrail:** Add `.env` and `.env.*` to `.gitignore` (keeping `!.env.example`), untrack the
live file with `git rm --cached .env`, and add a CI check that fails when any `.env` file is
tracked. Ship a committed `.env.example` containing only the key *names*, so a fresh clone
knows what to supply.

The rule is the ignore-plus-untrack combination, not the ignore rule alone. An ignore rule
that does not also untrack the file leaves the repository in a state that looks protected and
is not, and nothing in a reviewer's normal workflow will catch it — the file is already in the
index and will not appear as a new change.

## Solution

### Immediate Fix
Not applied. The user asked for the frontend work to be committed; untracking `.env` changes
the repository's behaviour for every other consumer of it, including the Lovable editor
session that syncs from this branch, and that call belongs to the user.

The commit was made without `git add -A` and without touching `.env`, so nothing was made
worse. The file remains exactly as it was.

### Long-term Fix
1. Add to `.gitignore`: `.env`, `.env.*`, `!.env.example`
2. `git rm --cached .env` (keeps the working file, untracks it)
3. Commit a `.env.example` with the six key names and empty values
4. Add a CI check that fails if `git ls-files` matches any `.env*` path

Note that step 2 does not remove the file from history. The values are publishable and are
already public via the client bundle, so no rotation is required — but if a service-role key
is ever added to this repository, rotation *and* history rewriting become necessary, and that
is materially harder to undo, especially on a branch connected to Lovable.

## Prevention
- [ ] Add the `.env` / `.env.*` ignore rules with `!.env.example`
- [ ] `git rm --cached .env`
- [ ] Commit `.env.example` with key names only
- [ ] Add a CI check rejecting tracked `.env` files
- [ ] Confirm no service-role key is ever written to a file in this repo

## Related Issues
- None. Found during a pre-commit secret scan for the step-5 commit.

## References
- `.env`, `.gitignore` in `pixel-perfect-replication`
- `WORKING-PROCESS.md` §6 (committing: review the diff, never `git add -A` blindly)

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** Open — 5-minute fix, awaiting the user's decision
