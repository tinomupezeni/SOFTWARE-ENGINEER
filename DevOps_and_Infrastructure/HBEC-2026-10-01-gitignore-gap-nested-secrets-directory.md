# `.gitignore` Pattern Doesn't Cover a Nested Secrets Directory That Shouldn't Exist

**Date:** 2026-10-01
**Project:** HBEC
**Environment:** Staging (VPS working copy), discovered during staging teardown
**Severity:** Medium (real secrets came within one failed push of reaching GitHub; caught before any actual leak)
**Status:** Resolved for this instance; the underlying gap and its root cause are open follow-ups

## Summary
While backing up real git stashes found on staging's working copy before
decommissioning it, `git stash -u` (which also captures untracked files)
swept up four real secret files — `pg_password.txt`,
`admin_secret_key.txt`, `harness_db_password.txt`,
`student_secret_key.txt` — into commits destined for GitHub backup
branches. The repo's `.gitignore` already has a rule for exactly this
secret-file pattern, but it only matches files one level deep
(`docker/secrets/*.txt`), and these files were sitting at
`docker/secrets/secrets/*.txt` — a nested, duplicate-looking directory
whose origin is unexplained. Two push attempts containing these secrets
failed before reaching GitHub (confirmed via `git ls-remote`, for unrelated
reasons — a read-only deploy key, then separately a workflow-scope
restriction), and every commit was inspected and the secret files stripped
out before any successful push. Nothing leaked, but the only reason it
didn't was two unrelated push failures, not the gitignore working as
intended.

## Symptoms
- `git stash branch <name> <stash>` followed by `git add -A` staged four
  files under `docker/secrets/secrets/` that should have been invisible to
  git entirely.
- `git check-ignore -v docker/secrets/secrets/pg_password.txt` returned
  nothing (not ignored), while the same check against
  `docker/secrets/pg_password.txt` (one level up) correctly matched the
  existing `.gitignore` rule.

## Environment Details
- **Server/Host:** Production VPS, staging's working copy
  (`/home/winstontino/HBEC`, a real git clone, now retired to
  `/sdb-disk/HBEC.retired-20261001`)
- **Related Components:** `.gitignore`, whatever process wrote files into
  `docker/secrets/secrets/` in the first place (not identified — see
  Follow-ups)

## Investigation Steps

### 1. Initial Diagnosis
A routine `git add -A && git commit` (part of preserving a stash as a
backup branch before deleting the directory) produced a commit containing
file paths that were clearly real secret material, not source code.

### 2. Root Cause Analysis
```bash
git check-ignore -v docker/secrets/secrets/pg_password.txt
# (no output — not ignored)
cat .gitignore | grep -i secret
# docker/secrets/*.txt
```
`docker/secrets/*.txt` is a single-level glob — it matches
`docker/secrets/pg_password.txt` but not `docker/secrets/secrets/
pg_password.txt`, since the extra path segment puts the file outside what
that pattern covers. Untracked files in a directory the pattern doesn't
reach are exactly what `git stash -u` and `git add -A` will happily pick
up.

### 3. Key Findings
- This is a narrow but real gap: the intent of the existing `.gitignore`
  rule (never let these specific secret files be tracked) is defeated by
  one extra directory level.
- **Why the nested directory exists at all is still unexplained.** It held
  the same four secret filenames `/opt/hbec/docker/secrets/` uses at the
  top level, which suggests some bootstrap or deploy step wrote secrets to
  the wrong nested path on this specific working copy — but no script in
  the repo was found that writes to `docker/secrets/secrets/` specifically
  (only to `docker/secrets/` directly, matching the gitignored pattern).
  This needs a dedicated look, since if something is still writing there,
  the directory could reappear.
- The two failed pushes that prevented an actual leak were coincidental,
  not protective: a read-only deploy key on the VPS, and separately a
  GitHub token missing `workflow` scope. Neither exists *because* of this
  gitignore gap — they just happened to be in the way both times.

## Root Cause
`.gitignore`'s secret-file pattern (`docker/secrets/*.txt`) only matches
files directly inside `docker/secrets/`, not inside any subdirectory of it
— so a file at `docker/secrets/secrets/*.txt` is untracked-but-not-ignored,
and any `-u`/`-A`-style git operation will treat it as ordinary content to
stage.

## Prevention / Rule
**Guardrail:** Widen the pattern to cover any depth —
`docker/secrets/**/*.txt` (or equivalently `docker/secrets/` as a bare
directory-ignore, if nothing legitimate needs version-controlled `.txt`
files anywhere under that tree) — so a secret file is excluded regardless
of how many directory levels deep it ends up, intentional or not.

This closes the gap because the actual failure mode was "one extra path
segment defeats an otherwise-correct rule," and a depth-agnostic pattern
has no such blind spot to begin with.

## Solution

### Immediate Fix (this instance)
The nested directory and its contents were deleted as part of retiring the
staging working copy entirely (see the accompanying report,
`reports/HBEC-2026-10-01-staging-vps-teardown.md`). Every backup branch
that had briefly contained these secret files was inspected
(`git show --stat`, `git ls-tree -r | grep -i secret`) and amended to
remove them before the successful push; the failed pre-fix pushes were
confirmed to have never reached GitHub via `git ls-remote`.

### Long-term Fix (not yet done)
- [ ] Widen `.gitignore`'s pattern to `docker/secrets/**/*.txt` (or
      directory-level ignore) in the main repo, so this can't recur on any
      other working copy (e.g. `/opt/hbec`, a future developer's local
      checkout).
- [ ] Identify what wrote to `docker/secrets/secrets/` on this specific
      staging working copy — not found in this investigation, and staging
      is now retired, but the same bootstrap step (if it exists elsewhere)
      could reproduce this on a different host.

## Prevention
- [ ] Widen the `.gitignore` pattern (see above) — not yet done, flagged
      here rather than actioned immediately since it touches the main
      repo and deserves its own small, reviewed change rather than being
      folded into the teardown work that found it.
- [x] Confirmed no secret values reached GitHub (`git ls-remote` checked
      after both failed push attempts, before any successful one).
- [x] All 4 eventual backup branches verified secret-free via `git ls-tree
      -r <branch> | grep -i 'secret\|password'` before pushing.

## Related Issues
- `HBEC-2026-10-01-staging-vps-teardown.md` — the broader teardown this
  was discovered during.

## References
- `.gitignore` (repo root)
- `/sdb-disk/HBEC.retired-20261001` (the retired working copy this was
  found on)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Caught and contained within the same session; the underlying gitignore gap remains open, tracked above.
