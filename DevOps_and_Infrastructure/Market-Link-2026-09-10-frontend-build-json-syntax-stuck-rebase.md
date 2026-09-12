# HtmlWebpackPlugin Build Failure — Unresolved Git Rebase Left Conflict Markers in package.json

**Date:** 2026-09-10
**Project:** Market-Link (agromarket)
**Environment:** Production (agromarketing-vm VPS)
**Severity:** High
**Status:** Resolved

## Summary
The frontend Docker container fails to build/start with an HtmlWebpackPlugin / webpack `ModuleNotFoundError`, ultimately caused by `SyntaxError: Expected double-quoted property name in JSON at position 510` when webpack tries to parse `/app/package.json`. Root cause: the repo on the VPS (`/home/user/Documents/agromarket`) has an **interactive git rebase stuck mid-conflict**, and literal, unresolved git conflict markers (`<<<<<<< HEAD` / `=======` / `>>>>>>>`) are present directly inside `frontend/package.json` and `backend/package.json`, making them invalid JSON. Since docker-compose bind-mounts `./frontend:/app` and `./backend:/app` (live source, not a baked image), the broken working-tree files are exactly what webpack sees inside the container.

## Symptoms
- `html-webpack-plugin` child compilation fails with `Module not found: SyntaxError: /app/package.json (directory description file): ... Expected double-quoted property name in JSON at position 510`
- Error repeats the same "directory description file" SyntaxError multiple times (webpack retrying package.json resolution up the directory tree)
- Frontend container (`marketlink_frontend`) never becomes healthy

## Environment Details
- **Server/Host:** agromarketing-vm (VPS)
- **Services Affected:** `marketlink_frontend` (frontend build/dev server); `marketlink_backend` has the identical underlying defect but wasn't the one reported failing
- **Related Components:** `docker-compose.yml` at `/home/user/Documents/agromarket/docker-compose.yml`, bind mounts `./frontend:/app` and `./backend:/app`
- **Time First Observed:** 2026-09-10

## Investigation Steps

### 1. Initial Diagnosis
SSH'd into `agromarketing-vm`. Docker CLI required `sudo` with an interactive password not available non-interactively, so diagnosed via the filesystem instead — the compose volumes mean the container's `/app/package.json` is literally the host file, so it can be inspected directly without touching Docker.

### 2. Root Cause Analysis
```bash
# Located the project and its compose file
find /home /opt /srv /var/www -maxdepth 5 -iname "docker-compose*.y*ml" 2>/dev/null

# docker-compose.yml confirmed bind mounts:
#   frontend: - ./frontend:/app
#   backend:  - ./backend:/app

# Validated the JSON directly
node -e "JSON.parse(require('fs').readFileSync('/home/user/Documents/agromarket/frontend/package.json','utf8'))"
# → SyntaxError: Expected double-quoted property name in JSON at position 510
#   (node printed the offending line: "<<<<<<< HEAD")

node -e "JSON.parse(require('fs').readFileSync('/home/user/Documents/agromarket/backend/package.json','utf8'))"
# → same failure, position 188, also on "<<<<<<< HEAD"

# Checked repo state
cd /home/user/Documents/agromarket && git status
# → "interactive rebase in progress; onto 2c1bbcc" ... "You are currently rebasing branch 'main' on '2c1bbcc'"
#   40+ files listed as "Unmerged paths" / "both added", including both package.json files
```

### 3. Key Findings
- The repo has been left in the middle of `git rebase -i` with unresolved conflicts since at least the commit that introduced `9337dfb` ("Initial MarketLink monorepo setup with backend and frontend") being replayed onto `2c1bbcc`.
- `frontend/package.json` has a real conflict block (lines 17–42) between two dependency sets — notably React 18 vs React 19, plus one side adding `ajv` and `react-scripts` pinned differently.
- `backend/package.json` has two smaller conflicts (npm scripts block, and the `nodemailer` dependency).
- `git diff --check` shows leftover conflict markers across ~40 files repo-wide (`.gitignore`, most of `backend/controllers/*`, `backend/routes/*`, `frontend/src/**/*.tsx`, etc.) — this is not isolated to `package.json`, the whole working tree is mid-conflict.
- Because the compose files bind-mount the working tree straight into the containers, any file left with conflict markers becomes live application/build code, not just a git metadata artifact.

## Root Cause
An interactive `git rebase` (`main` onto `2c1bbcc`, replaying `9337dfb` and later commits) was started on the VPS and abandoned with conflicts unresolved. Because the frontend/backend containers run against the live bind-mounted working tree, the still-conflicted `package.json` files (containing literal `<<<<<<<`/`=======`/`>>>>>>>` markers) are invalid JSON, which Node's `require`/JSON parser (used internally by webpack/html-webpack-plugin to read the nearest `package.json` as the module "directory description file") rejects — surfacing as the reported `ModuleNotFoundError`/`SyntaxError`.

## Prevention / Rule
**Guardrail:** A pre-deploy/CI check that fails fast if `git status` shows an in-progress rebase/merge, or a repo-wide grep for `<<<<<<<` finds conflict markers anywhere in the tree — before any build or container recreate is allowed to proceed.

Bind-mounting the live working tree into production containers means a stuck git operation becomes a live application defect, not just an inconvenience — the check needs to run before every deploy, not be discovered by a user-facing build failure.

## Solution

### Immediate Fix
Repo owner (Tino) resolved the conflicts and ran `git rebase --continue` on 2026-09-10 evening. Verified in the 2026-09-11 follow-up session (see `Market-Link-2026-09-11-stale-images-not-rebuilt.md`): `.git/rebase-merge` is gone, no conflict markers remain anywhere in the tree, and both `frontend/package.json` and `backend/package.json` parse as valid JSON. `main` is now a clean fast-forward descendant of `origin/main` (`2c1bbcc`) plus 11 additional local commits.

### Long-term Fix
- Never leave an interactive rebase open on a production VPS working tree that is live bind-mounted into running containers — a stuck rebase directly breaks the running app, not just local dev.
- Consider building a deployable image (COPY, not bind-mount) for production compose, so an in-progress local git operation can't take down the running service.

## Prevention
- [ ] Add a pre-deploy/CI check that fails fast if `git status` shows an in-progress rebase/merge or `git diff --check` finds conflict markers
- [ ] Consider switching production `docker-compose.yml` from bind-mounting `./frontend`/`./backend` into `/app` to a proper multi-stage build (`COPY . .` in the Dockerfile) so container state isn't tied to the host working tree's git state
- [ ] Document the intended base commit for the `main` rebase so this doesn't get abandoned again

## Related Issues
- [[Market-Link-2026-09-11-stale-images-not-rebuilt]] — discovered while investigating a stale-deployment report; confirmed this rebase had completed.
- [[Market-Link-2026-09-11-react-version-mismatch-frontend-build]] — this rebase's conflict resolution also left `react`/`react-dom` on an incompatible v19, surfaced when the first post-rebase rebuild was attempted.

## References
- `docker-compose.yml`: `/home/user/Documents/agromarket/docker-compose.yml`
- Conflicted files: `frontend/package.json`, `backend/package.json`, plus ~40 more (see `git diff --check` output in this session)

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** Root cause found in ~10 minutes; resolution pending owner's merge decision
