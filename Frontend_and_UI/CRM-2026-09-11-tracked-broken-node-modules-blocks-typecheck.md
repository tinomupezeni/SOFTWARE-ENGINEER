# Frontend node_modules Partially Tracked in Git and Broken (tsc/build fails)

**Date:** 2026-09-11
**Project:** CRM Professional
**Environment:** Development (Linux, Claude Code sandbox)
**Severity:** Medium (blocks local typecheck/build)
**Status:** Resolved

## Summary
`frontend/node_modules/` is listed in `.gitignore` (`node_modules/`), but `git status` shows tracked, modified files inside `node_modules/typescript/` (and `.bin/tsc`, `.bin/tsserver`) — meaning these were force-added to a commit at some point, bypassing the ignore rule. The committed copies are incomplete: `node_modules/typescript` has no `lib/` directory at all, and packages like `react-router-dom`, `react-hook-form`, `@reduxjs/toolkit` only contain `LICENSE.md`/`README.md`/`package.json` with no actual dist/type files.

## Symptoms
- `npm run build` / `tsc -b --noEmit` fails immediately: `Error: Cannot find module '../lib/tsc.js'`.
- After reinstalling `typescript` locally, `tsc` instead reports `Cannot find module 'react-router-dom'`, `'react-hook-form'`, `'@reduxjs/toolkit'`, `'react-redux'` etc. across nearly every feature file — not real type errors, just missing package contents.

## Root Cause
A partial/corrupted `node_modules` was committed to git despite `.gitignore` excluding `node_modules/`, most likely from a `git add -f` or an editor/tool that bypassed the ignore rule. Because it's tracked, a fresh `npm install` doesn't fully repair it (npm considers already-present tracked files as satisfying the dependency) until those specific package directories are removed and reinstalled individually.

## Solution

### Workaround (used this session)
```bash
rm -rf node_modules/typescript
npm install typescript@5.9.3 --no-save   # restores lib/, bin works again
```
This was reverted afterward (`git checkout -- node_modules/`) to avoid committing more stray `node_modules` diffs on top of the existing problem.

### Long-term Fix (applied)
```bash
git rm -r --cached frontend/node_modules   # untrack, keep gitignore rule
rm -rf frontend/node_modules && npm install  # clean, complete reinstall
```
Committed as `21fb075` — "Stop tracking frontend/node_modules (already gitignored)". `npm run build` (`tsc -b && vite build`) now completes cleanly with zero errors, confirming the missing-module noise was entirely this tracked/broken install and not a real code issue. Every other dev/clone just needs `npm install` once after pulling this commit; git history itself was not rewritten (the old tracked blobs remain in history, only the current tree is untracked), so no force-push or history surgery was needed.

## Prevention
- [x] Remove `frontend/node_modules` from git tracking (commit `21fb075`).
- [ ] Add a pre-commit check or CI guard that fails if any path under `node_modules/` is staged, to stop this from happening again via a stray `git add -f`.
- [x] Confirmed via full `npm run build` that no real type errors were hiding behind the noise.

---

**Resolved By:** Claude Code
**Time to Resolution:** ~15 minutes (untrack + clean reinstall + verified full build)
