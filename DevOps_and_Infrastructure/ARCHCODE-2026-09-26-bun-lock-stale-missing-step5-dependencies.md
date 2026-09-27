# `bun.lock` has never been regenerated, so it does not contain any step-5 dependency

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** High
**Status:** Open — blocked on bun not being installed

## Summary
The repo is bun-managed: `bun.lock` is tracked and `bunfig.toml` enforces a 24-hour
`minimumReleaseAge` supply-chain guard. Step 5 added eight CodeMirror dependencies to
`package.json`, and every one of them is absent from `bun.lock`. Because bun is not installed
in this environment, the dependencies were installed with `npm install` instead — which both
bypassed the 24h release-age guard and produced a `package-lock.json` that has been deleted as
foreign to the repo. The working tree builds and passes, but the committed lockfile does not
describe it, so a clean `bun install` on another machine resolves a different dependency set
than the one verified here.

## Symptoms
- All eight step-5 dependencies show zero occurrences in `bun.lock`.
- `bun install` on a fresh clone would not install the editor at all, or would resolve
  different versions than those verified.
- `npm install` was required locally, which quietly opts the whole install out of the
  `minimumReleaseAge` policy the repo configured on purpose.
- Two package managers now both believe they own the project; only one lockfile is tracked.

## Environment Details
- **Server/Host:** local dev machine
- **Services Affected:** `package.json`, `bun.lock`, `bunfig.toml`
- **Related Components:** entire install pipeline
- **Time First Observed:** 2026-09-26, while adding `@codemirror/search`

## Investigation Steps

### 1. Initial Diagnosis
Added a direct `@codemirror/search` dependency, then checked whether the lockfile needed
updating and found bun was not on `PATH`.

### 2. Root Cause Analysis
```bash
for p in @codemirror/state @codemirror/view @codemirror/language @codemirror/search \
         @codemirror/lang-python @codemirror/commands @codemirror/lang-sql codemirror; do
  printf '%-26s lock:%s\n' "$p" "$(grep -c "\"$p\"" bun.lock)"
done
# all 0

command -v bun        # -> not installed
cat bunfig.toml       # minimumReleaseAge = 86400
ls package-lock.json  # created by npm install; removed (twice — it reappeared)
```

### 3. Key Findings
- `bun.lock` is `lockfileVersion 1` and predates the whole step-5 dependency set. It does
  contain `react-resizable-panels`, so it is not empty — it is specifically stale.
- `bunfig.toml` sets `minimumReleaseAge = 86400` with an explicit allow-list. Using npm
  install means the verified install is not reproducible under the repo's own policy, and the
  policy was not enforced for the eight newest packages.
- `npx` / `npm run` re-created `package-lock.json` after it was removed, so it must be
  deleted as the final action and verified in the same step; leaving it would risk committing a
  second lockfile.
- `package-lock.json` is untracked, so the risk is adding it, not having committed it.

## Root Cause
The environment lacks the package manager the project standardises on. Rather than stop, the
work proceeded with `npm`, which is functionally equivalent for resolution but differs in two
ways that matter here: it writes a different lockfile, and it ignores `bunfig.toml`. The
result is a verified working tree whose lockfile state cannot be reproduced, and a supply-chain
guard that was silently skipped for exactly the newest dependencies in the project.

## Prevention / Rule
**Guardrail:** In `scripts/`, add a lockfile-drift check that fails when any dependency in
`package.json` is missing from `bun.lock`, and fail if a `package-lock.json` or
`yarn.lock` exists alongside a tracked `bun.lock`. Wire it into `npm run verify` (or the bun
equivalent) so drift cannot survive a session.

Lockfile drift is invisible by construction: the build succeeds, typecheck passes, and every
assertion passes, because nothing in the toolchain compares `package.json` against the tracked
lockfile. The check has to be explicit, and it has to assert *both* directions — a declared
dependency absent from the lock, and a foreign lockfile present on disk.

## Solution

### Immediate Fix
- Added all eight CodeMirror packages as direct `dependencies` in `package.json` (the editor
  imports `@codemirror/*` directly rather than going through a wrapper, so each is a genuine
  direct dependency).
- Removed the stray `package-lock.json`.
- Left `bun.lock` untouched rather than hand-editing it: the text lockfile encodes a resolved
  graph with integrity hashes, and a hand-written entry is worse than an out-of-date one.

### Long-term Fix
Install bun and run `bun install` to regenerate `bun.lock` from scratch, then re-run the full
verification against a bun-installed tree. This also re-applies the 24h release-age guard, so
the resolution may legitimately differ from the npm-installed one and the suite must pass
again afterwards.

Blocked pending a decision on installing bun (or explicitly shipping with the drift documented).

## Prevention
- [x] All eight dependencies declared directly in `package.json`
- [x] `package-lock.json` removed
- [ ] Install bun and regenerate `bun.lock`
- [ ] Re-run `verify`, typecheck, ESLint, build, and the CDP suites on the bun-installed tree
- [ ] Add the package.json↔bun.lock drift check and the foreign-lockfile check
- [ ] Confirm the four `minimumReleaseAgeExcludes` entries are still needed

## Related Issues
- `reports/ARCHCODE-2026-09-26-step5-product-surface.md`

## References
- `package.json`, `bun.lock`, `bunfig.toml` (`minimumReleaseAge = 86400`)
- `npm install` bypassing `bunfig.toml`

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** Open; install verified with npm, lockfile regeneration pending
