# Frontend Build Failure — React 19 Left in package.json After Rebase, Incompatible With Chakra UI/Framer Motion

**Date:** 2026-09-11
**Project:** Market-Link (agromarket)
**Environment:** Production (agromarketing-vm VPS, `10.50.101.17`)
**Severity:** High
**Status:** Resolved

## Summary
While rebuilding the frontend Docker image (see `Market-Link-2026-09-11-stale-images-not-rebuilt.md`), `npm install` failed with an ERESOLVE peer-dependency conflict: `frontend/package.json` declared `react@^19.2.0`/`react-dom@^19.2.0` (and `@types/react@^19.2.2`/`@types/react-dom@^19.2.2`), but `@chakra-ui/react@2.10.9` and `framer-motion@10.18.0` both require React 18 as a peer. This was a leftover mis-resolution from the interactive rebase documented in `Market-Link-2026-09-10-frontend-build-json-syntax-stuck-rebase.md` — that rebase's conflict list explicitly called out "React 18 vs React 19" as one of the real conflicts in `frontend/package.json`, and whoever resolved it picked the React 19 side for `react`/`react-dom`/their `@types` packages without upgrading Chakra UI or Framer Motion to compatible versions.

## Symptoms
- `docker compose build --no-cache frontend` failed at the `npm install` layer:
  ```
  npm error ERESOLVE could not resolve
  npm error peerOptional react@"^18.0.0" from framer-motion@10.18.0
  npm error peer react@"^18.0.0" from @chakra-ui/hooks@2.4.5
  ```
- Secondary conflict on type packages: `@types/react-dom@18.3.7` requires `@types/react@^18.0.0`, but root declared `@types/react@^19.2.2`.

## Environment Details
- **Server/Host:** agromarketing-vm (10.50.101.17)
- **Services Affected:** `marketlink_frontend` (build-time only; container was still running the old image until this was fixed)
- **Related Components:** `/home/user/Documents/agromarket/frontend/package.json`, `package-lock.json`
- **Time First Observed:** 2026-09-11 (during rebuild triggered by the stale-images investigation)

## Investigation Steps

### 1. Initial Diagnosis
`docker compose build --no-cache backend frontend` — backend built fine, frontend failed with the ERESOLVE error above.

### 2. Root Cause Analysis
Compared the checkout's `frontend/package.json` against both known-good remotes:
```bash
git show 2c1bbcc:frontend/package.json | grep -E '"(react|@chakra-ui/react|framer-motion)"'   # origin/main tip
git show torto/main:frontend/package.json | grep -E '"(react|@chakra-ui/react|framer-motion)"' # independent fork
```
Both agreed: `react@^18.2.0`, `@chakra-ui/react@^2.8.0`, `framer-motion@^10.16.4`. Only the local checkout had `react@^19.2.0`. Checked `frontend/package-lock.json`, which had actually resolved `react@19.2.5` — confirming `npm install` had previously been run successfully against the bad version (not just a manual `package.json` edit that was never installed).

### 3. Key Findings
- `git log --oneline -- frontend/package.json` shows the file hasn't been touched by a normal commit since the initial monorepo setup — the React 19 bump was introduced by the interactive rebase's conflict resolution (picking one side of a real conflict), not a deliberate dependency upgrade commit.
- `@types/react`/`@types/react-dom` had the same 19.x-vs-18.x mismatch.
- No other dependency in the tree wanted React 19; Chakra UI 2.x and this version of Framer Motion are React-18-only.

## Root Cause
During the 2026-09-10 rebase conflict resolution, the `react`/`react-dom` (and corresponding `@types/*`) conflict in `frontend/package.json` was resolved by keeping the React 19 side, while every other React-19-incompatible dependency (`@chakra-ui/react`, `framer-motion`) was left untouched from the React-18-era lockfile. This produced a `package.json`/`package-lock.json` that could pass a stale, already-resolved `node_modules` locally but fails a clean `npm install` — exactly what happens inside a Docker build.

## Prevention / Rule
**Guardrail:** A CI job that runs `npm ci` (never `npm install`, which can silently rewrite the lockfile to paper over a mismatch) against a clean checkout on every push, including merge/rebase commits.

`npm ci` fails hard on exactly this class of problem — a `package.json`/`package-lock.json` pair that only resolves against a stale local `node_modules` — so a one-sided rebase conflict resolution would have been caught in CI before it ever reached a production Docker build.

## Solution

### Immediate Fix
Reverted `react`, `react-dom`, `@types/react`, `@types/react-dom` to the versions agreed on by both `origin/main` and the `torto` fork, then regenerated the lockfile cleanly:
```bash
cd /home/user/Documents/agromarket/frontend
# package.json: react/react-dom -> ^18.2.0, @types/react -> ^18.3.3, @types/react-dom -> ^18.3.0
rm -f package-lock.json
npm install --package-lock-only   # resolved cleanly, no ERESOLVE warnings
docker compose build --no-cache frontend   # succeeded
```
Verified via `docker compose up -d` + `curl` that the frontend serves HTTP 200 afterward.

### Long-term Fix
- Don't resolve real semantic dependency conflicts (major version bumps) via an interactive rebase without immediately running a clean `npm install` (or CI build) to catch cross-package incompatibilities before committing.
- If a React 19 upgrade is ever wanted, it needs to be a deliberate, tested upgrade of Chakra UI (v3, which supports React 19) and Framer Motion together — not a one-sided rebase pick.

## Prevention
- [ ] Add a CI step that runs `npm ci` (not `npm install`, which can silently rewrite the lockfile) on every push, so a broken dependency tree fails before it reaches the VPS
- [ ] After any rebase/merge touching `package.json`, require a clean install verification before committing

## Related Issues
- [[Market-Link-2026-09-10-frontend-build-json-syntax-stuck-rebase]] — same rebase event; that entry covers the literal conflict-marker/JSON-syntax break, this one covers the semantic dependency mis-resolution left after the markers were cleaned up.
- [[Market-Link-2026-09-11-stale-images-not-rebuilt]] — this issue was only discovered because that investigation triggered the first rebuild in 3 weeks.

## References
- `frontend/package.json`, `frontend/package-lock.json`: `/home/user/Documents/agromarket/frontend/`

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** ~20 minutes
