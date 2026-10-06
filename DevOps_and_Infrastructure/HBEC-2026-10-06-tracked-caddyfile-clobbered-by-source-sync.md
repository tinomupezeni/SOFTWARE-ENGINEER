# Generated Caddyfile was tracked in git, clobbered by the VPS source sync

**Date:** 2026-10-06
**Project:** HBEC
**Environment:** Production (`hbca-vps`)
**Severity:** High (live near-miss — caught immediately, no real traffic misrouted)
**Status:** Resolved

## Summary
`docker/caddy/Caddyfile` is declared generated output by its own header
comment ("Never edit by hand — the next cutover/rollback overwrites this
file") and is regenerated at runtime by `scripts/deploy/render-caddyfile.sh`
from the `active_color` marker. It was nonetheless still tracked in git with
a stale, pre-blue-green committed version. The manual deploy process's VPS
source sync (`git reset --hard origin/master`, used to update `/opt/hbec`
before each deploy round) silently reverted the live, correctly-generated
file back to that stale version — undoing the green cutover at the config
level, on disk, with no warning.

## Symptoms
- Ran the routine VPS source sync before a blue rebuild; `git reset --hard`
  reported no errors.
- Immediately after, `cat /opt/hbec/docker/caddy/Caddyfile` showed
  `reverse_proxy hbec-student-frontend:80` (the pre-cutover unsuffixed
  hostname) instead of `hbec-student-frontend-green:80`.
- Public domains still returned `200` throughout — Caddy's in-memory
  config had not yet reloaded, so no real request was actually misrouted
  during the window the file was wrong on disk.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** none in practice (caught before any reload) — would
  have been all public traffic (student/admin/payments/schools) had
  anything triggered a Caddy reload or gateway container restart before
  the fix
- **Related Components:** `docker/caddy/Caddyfile`, `active_color`,
  `scripts/deploy/render-caddyfile.sh`, the manual deploy process's source
  sync step
- **Time First Observed:** 2026-10-06, during routine VPS sync ahead of a
  blue rebuild

## Investigation Steps

### 1. Initial Diagnosis
Checked the live Caddyfile content immediately after the sync as a matter
of habit (recent history this session: the same file had just been fixed
from a hand-edited to a properly-generated state) — caught the reversion
within the same command sequence, before moving on to anything else.

### 2. Root Cause Analysis
```bash
git ls-files docker/caddy/Caddyfile   # -> tracked (should not be)
```
`active_color` (the actual source of truth) was confirmed untouched and
still correct (`green`) — it was never tracked in git, so the sync left it
alone. Only the generated artifact that happened to also be committed was
affected.

## Root Cause
A generated, runtime-only artifact was tracked in git alongside the
deploy process's own `git reset --hard` sync step, which by design
discards any local, uncommitted state on tracked files — exactly what the
live-generated Caddyfile always is, every time `render-caddyfile.sh` runs.

## Prevention / Rule
**Guardrail:** a generated artifact that a runtime script owns must never
also be tracked in git — the two will diverge the first time anything
syncs the tracked copy, and the sync has no way to know the local version
is the one that matters. `active_color` already followed this rule
correctly (untracked from the start); the Caddyfile did not.

## Solution

### Immediate Fix
Re-ran `scripts/deploy/render-caddyfile.sh` with the still-correct
`active_color=green` marker, restoring the live Caddyfile and reloading
Caddy. Verified: real traffic (confirmed via `admin-frontend-green`'s
access log showing an actual user session, not just synthetic checks)
flowing to green again; the unsuffixed container's logs show only a local
healthcheck probe, confirming it correctly receives no public traffic.

### Long-term Fix
`git rm --cached docker/caddy/Caddyfile` + added to `.gitignore` (commit
`ad0a5ab9`) — matching `active_color`'s own untracked, runtime-only
treatment.

**One more wrinkle hit applying this fix, worth recording:** the VPS's next
source sync (pulling commit `ad0a5ab9` itself) *deleted* the file entirely —
`git reset --hard` removes a working-tree file when moving to a target
commit that no longer tracks it, which is exactly what happened the one
time the tracked→untracked transition itself had to cross that sync. Caught
immediately (checked right after, out of habit from the first catch) and
fixed the same way (`render-caddyfile.sh` regenerates it from `active_color`
regardless of whether the file existed a moment before). Confirmed
afterward: `git ls-files` returns nothing for this path on the VPS now, so
no future sync can repeat either failure mode — this was strictly a
one-time cost of the transition, not a standing gap.

## Prevention
- [x] Untracked the file, added to `.gitignore`
- [ ] Audit for any other runtime-generated file that is still tracked in
      git elsewhere in the repo (not done this session — worth a repo-wide
      sweep given this is the second "two sources of truth" finding
      involving this exact file in two days)

## Related Issues
- `reports/HBEC-2026-10-06-green-cutover.md` (where the original
  `active_color`/Caddy mismatch was first found and fixed — this is the
  same class of problem recurring one layer down, in git instead of in
  the runtime marker)

## References
- `scripts/deploy/render-caddyfile.sh`
- Commit `ad0a5ab9`

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Caught and fixed within the same session, before
any real traffic was affected.
