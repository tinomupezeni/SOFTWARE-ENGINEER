# Production VM Had Hand-Edited Hotfixes Never Committed to Git

**Date:** 2026-10-06
**Project:** Market-Link
**Environment:** Production
**Severity:** Medium
**Status:** Resolved (partially — see Follow-ups)

## Summary
Asked to confirm the code running on the production VM
(`agromarket-vm`, `10.50.101.17`) matched local, a diff against both local
and `origin/main` showed production's working tree
(`/home/user/Documents/agromarket`, the directory Docker Compose actually
builds `marketlink_backend`/`marketlink_frontend` from) had four files
modified beyond its committed `HEAD` (`8420ace`, identical to
`origin/main` at the time) — and none of the four had ever been committed:

1. `backend/controllers/authController.js` — removed the `farmSize`
   required-field validation block for farmer registration.
2. `backend/models/User.js` — changed `farmName`/`cropCategories`/
   `farmSize` schema `required` functions from `this.role === 'farmer'` to
   an unconditional `false`.
3. `frontend/src/services/api.ts` — replaced hostname-sniffing
   (`window.location.hostname.includes('agromarketing.co.zw')`) with
   `process.env.REACT_APP_API_URL || '/api'`.
4. `frontend/.env` — modified (not diffed/logged here; low-sensitivity
   content, a port and a localhost URL, but handling left to the user per
   this session's credential-leakage guardrail).

Item 3 turned out to be a fix already independently made and committed
locally (`d280a37`, "remove hardcoded domain sniffing and use env vars for
API URL to prevent regression") — byte-identical diff, just never landed
on the VM's git history. Items 1–2 had no equivalent anywhere else; they
existed only as uncommitted production drift.

## Symptoms
- No incident reported this triggered it — surfaced only by a direct
  "does the VM match local" request, with no prior signal that production
  and git had diverged.

## Environment Details
- **Server/Host:** `agromarket-vm` (`10.50.101.17`), working dir
  `/home/user/Documents/agromarket` (confirmed via
  `docker inspect marketlink_backend` → `com.docker.compose.project.working_dir`)
- **Services Affected:** `marketlink_backend`, `marketlink_frontend`
  (Docker Compose, built from this working tree)
- **Related Components:** git remote `PearsonMunasheTorto/Market-Link`,
  branch `main`
- **Time First Observed:** 2026-10-06

## Investigation Steps

### 1. Initial Diagnosis
Compared `git log --oneline` and `git diff --stat` across three points:
local working tree, local's view of `origin/main`, and the VM's working
tree (reached over a newly configured SSH alias, `agromarket-vm`).

### 2. Root Cause Analysis
```bash
docker inspect marketlink_backend --format '{{json .Config.Labels}}'
# -> com.docker.compose.project.working_dir: /home/user/Documents/agromarket
ssh agromarket-vm "cd /home/user/Documents/agromarket && git status && git log --oneline -5"
```
VM's committed `HEAD` matched `origin/main` exactly — no commit-graph
divergence. The entire gap was uncommitted working-tree edits on the VM
that had never been staged, committed, or pushed since whatever deploy or
hands-on session introduced them.

### 3. Key Findings
- The VM has no stored GitHub credentials (`git ls-remote origin` failed
  with "could not read Username") — so even if someone had tried to
  commit+push from the VM, pushing would have required setting up fresh
  credentials there, which likely discouraged it in the first place and
  left the edits sitting uncommitted indefinitely.
- Multiple stale/duplicate project checkouts exist on the VM
  (`Documents/agromarket.archived-2026-09-12`, `Documents/Market-Link-main`,
  `Downloads/Market-Link-main`, `Downloads/Market-Link-main (2)`,
  `Downloads/project`) — only `Documents/agromarket` is the one Compose
  actually builds from; the others are dead weight that could mislead a
  future session into diffing/editing the wrong tree.

## Root Cause
Production deploys/hotfixes on this VM are made directly in the working
tree that Docker Compose builds from, with no requirement (and, until this
session, no working credential path) to commit and push those edits back
to git. Nothing enforces that the tree driving the live containers stays
in sync with the tracked repo, so fixes applied by hand to unblock
production silently never make it back upstream.

## Prevention / Rule
**Guardrail:** Set up git push credentials on the VM (or route all
hotfixes through a documented "commit locally → push via an SSH-reachable
remote, never leave it uncommitted" step) and add this exact check — diff
the VM's git `HEAD`-plus-working-tree against `origin/main` — as a
recurring step before any deploy or incident response touching this VM,
the same way `HBEC-2026-09-13-production-litellm-config-drift-from-git.md`
recommends for bind-mounted config. Bare file-level production edits with
no commit step are the single mechanism behind both incidents.

## Solution

### Immediate Fix
- Committed the three non-`.env` files on the VM as `ae2cfbc` (preserving
  the VM's existing git identity, `Manzini-Emmanuel`), using the VM's own
  git, no new credentials needed for a local commit.
- Fetched that commit directly into local over the already-configured
  `agromarket-vm` SSH alias (`git fetch ssh://agromarket-vm/home/user/Documents/agromarket main`)
  rather than provisioning GitHub push credentials on the VM — avoids
  creating a new credential surface there for what was a one-off sync.
- Stashed local's own unrelated uncommitted work (new Swagger API docs:
  `backend/swagger.yaml`, `backend/server.js` wiring, `package.json`/
  `package-lock.json` deps), merged the VM's commit cleanly (no conflicts —
  disjoint file sets, and the one overlapping file, `api.ts`, was already
  byte-identical), restored the stash, and pushed the merge to
  `origin/main` (`8420ace..1d198a4`).

### Long-term Fix
See Prevention/Rule above — give the VM a real, documented path to push
its own commits, and make pre-deploy drift-diffing routine.

## Prevention
- [ ] Configuration changes needed — provision GitHub push credentials (or
      an SSH deploy key) on `agromarket-vm` so future hotfixes can be
      pushed from where they're made
- [ ] Monitoring/alerts to add — none yet; a scheduled drift-diff check
      would be the equivalent of the litellm guardrail
- [ ] Documentation to update — note the duplicate/stale checkout
      directories on the VM so a future session doesn't diff the wrong one
- [x] Code changes required — done (see Immediate Fix)

## Related Issues
- `DevOps_and_Infrastructure/HBEC-2026-09-13-production-litellm-config-drift-from-git.md`
  — same root cause shape (production diverges from git with no
  mechanism forcing sync), different project and artifact (a bind-mounted
  config file there vs. an uncommitted app-code working tree here).

## References
- `docker-compose.yml` in `/home/user/Documents/agromarket` on the VM
- `~/.ssh/config` entry `agromarket-vm` (this session's own setup)

---

**Resolved By:** tinomupezeni (via Claude Code session)
**Time to Resolution:** Same session

## Follow-ups
- `frontend/.env` on the VM is still uncommitted — left alone per this
  session's credential-leakage safeguard (the automation blocked
  materializing its diff/committing it even though manual inspection of
  local's copy showed only a port and a localhost URL, nothing sensitive).
  The user should review and commit or discard it directly.
- The relaxed farmer-registration validation (`authController.js`/
  `User.js`) was committed and pushed as-is at the user's explicit
  direction, without further review of whether loosening those fields was
  intentional product behavior or an in-progress, unfinished change.
