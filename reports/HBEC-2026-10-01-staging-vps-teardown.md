# Blue-Green: Staging VPS Teardown (Real Infrastructure)

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Infrastructure Decommission
**Status:** Completed

## Summary
Retired staging's entire footprint on the real VPS, completing the
staging-retirement work whose repo-side half had already merged
(`HBEC-2026-10-01-blue-green-*` reports). This is the first piece of the
blue-green rollout to touch real, live infrastructure rather than an
isolated dry run or repo-only changes: production's `gateway` container was
recreated (off `staging-edge-net`), 34 staging containers were stopped, 16
staging volumes and several staging-tagged images were removed, and the
staging working directory itself was retired. Production was verified
untouched throughout except for the one deliberate `gateway` recreate.

## Context / Trigger
Direct continuation of the blue-green rollout plan's staging-retirement
step, deferred from the repo-side PR specifically because it required
confirming `gateway` recreates cleanly without `staging-edge-net` before
that network was actually removed — a live-infrastructure action that
needed its own careful sequencing, not bundled into a code review.

## Scope
**Included**: recreating `gateway` without `staging-edge-net`; removing the
now-dead `staging-*.hbca.tech` site blocks from the live Caddyfile; backing
up and preserving three real git stashes plus a set of loose working-tree
modifications found on staging's working copy; stopping and removing every
staging container, volume, and staging-tagged image; removing the
`staging-edge-net` network; retiring the staging working directory.

**Explicitly excluded**: the real blue-green bootstrap itself (standing up
`-blue` containers, the first real cutover) — a separate, later, higher-
stakes step with its own approval gate.

## Method
Verify-before-destroy at every stage, consistent with this session's
established discipline: diffed every file before copying it to `/opt/hbec`,
confirmed `gateway` healthy and all public domains still serving *before*
touching the network, confirmed zero uncommitted git state remained on
staging's working copy *before* deleting it, and moved the retired
directory aside (on the secondary drive, at no cost) rather than an
immediate irreversible `rm -rf`.

## Decisions & Findings

### A near-miss with real secrets, caught before anything leaked
Backing up staging's git stashes (`git stash -u`, to also capture untracked
files) swept up real secret files (`pg_password.txt`,
`admin_secret_key.txt`, etc.) sitting at a nested `docker/secrets/secrets/`
path — one level deeper than the `.gitignore` pattern
(`docker/secrets/*.txt`) actually covers. Two attempts to push a branch
containing these secrets failed *before* reaching GitHub (confirmed via
`git ls-remote` returning nothing for the branch both times — the failures
were for unrelated reasons: a read-only deploy key, then a workflow-scope
restriction that happened not to apply here, and separately a `zsh`
parameter-expansion quirk mangling a colon in a refspec). Every commit was
inspected and the secret files stripped before any successful push. See
Follow-ups — the `.gitignore` gap and the stray nested directory are both
real findings worth fixing, independent of this teardown.

### `git stash branch` checks out the stash's original base commit, not the current branch tip
Each of the three original stashes had been sitting since well before many
subsequent commits landed on master — recovering them via `git stash
branch` correctly preserves their own small diff, but a naive `diff
backup-branch master` wildly overstates the change (it also shows every
intervening commit's worth of drift). The correct way to inspect "what does
this stash actually add" is `git show --stat HEAD` against the backup
commit's own immediate parent, not against current master.

### The Caddyfile needed a content fix, not just a network change
Dropping `gateway` from `staging-edge-net` left the Caddyfile's own
`staging-*.hbca.tech` site blocks pointing at now-unreachable upstreams —
visible immediately as repeated Let's Encrypt certificate-renewal failures
in `gateway`'s logs for those domains. Removed the blocks entirely (both
the live file and the repo's committed copy), rather than leaving dead
config that would keep failing silently.

### Reclaiming staging's footprint fixed a real standing problem, not just cleanup
Primary disk usage dropped from 151G/72% (this session's baseline) to
119G/57% — 32G reclaimed overall, most of it (35.68GB) from build cache
that had never been pruned. This directly improves the margin on an
already-documented past "production disk near-full" incident, not just
tidiness.

## Changes Made
- **Repo** (`master`, two commits): removed `staging-edge-net` from
  `gateway`'s networks and the network declaration itself (already part of
  the merged blue-green/staging-retirement PRs); a follow-up commit
  removing the now-dead `staging-*` Caddyfile blocks.
- **VPS, `/opt/hbec`**: `docker-compose.production.yml` replaced with the
  current repo version (first time any blue-green content landed on real
  `/opt/hbec` — only `gateway` was actually recreated from it, everything
  else profile-gated or otherwise untouched); `docker/caddy/` directory
  created (the bind-mount-directory fix) with the cleaned Caddyfile; new
  deploy scripts (`ensure-networks.sh`, `render-caddyfile.sh`, updated
  `verify-service-links.sh`) copied into place.
- **VPS, staging**: 34 containers stopped and removed; 16 staging-named
  volumes removed; staging-tagged images untagged; `hbec-staging_edge-net`
  and staging's other owned networks removed; `/home/winstontino/HBEC`
  symlink removed, real directory moved to
  `/sdb-disk/HBEC.retired-20261001` (not yet hard-deleted — a deliberate,
  no-cost grace window given 851GB remains free on that drive).
- **GitHub, 4 new branches**: `backup/staging-loose-modifications`,
  `backup/staging-stash-replication-wip`, `backup/staging-stash-litellm-
  alerts`, `backup/staging-stash-exam-practice-fix` — every piece of
  uncommitted work found on staging's working copy, preserved, secret
  files excluded.

## Verification
- `gateway` confirmed on `hbec_edge-net` only (not `staging-edge-net`)
  immediately after recreation, before any further destructive step.
- All public domains (`student`, `admin`, `school`, `api/v1/payments`)
  returned their expected status codes before and after every step.
- `hbec-student-backend`/`hbec-admin-backend`/`hbec-postgres` container
  start timestamps unchanged throughout — confirmed untouched except the
  one deliberate `gateway` recreate (whose own new start time is the
  expected, intended change).
- Zero staging containers remain (`docker ps -a --filter name=staging`
  returns none); zero staging networks remain (`docker network ls`).
- All 4 backup branches verified secret-free via `git ls-tree -r | grep`
  across every one, before pushing.
- Disk usage improved (151G/72% → 119G/57% primary; secondary drive
  unaffected at 20G/3% used, 851G free).

## Follow-ups / Deferred
- **`.gitignore` gap**: `docker/secrets/*.txt` doesn't cover a nested
  `docker/secrets/secrets/*.txt` path, which is exactly what let real
  secrets slip into an untracked-file sweep. Worth a broader pattern
  (`docker/secrets/**/*.txt` or similar) so this can't recur.
- **Unexplained nested secrets directory**: `docker/secrets/secrets/` on
  staging's working copy held real secret files with no obvious owner —
  worth a quick look at what process created it, though staging itself is
  now retired so the immediate risk is gone.
- The real blue-green bootstrap (`-blue` containers, validating against the
  live DB, the first real cutover) remains the next, separate, higher-
  stakes step — not started by this work.
- `/sdb-disk/HBEC.retired-20261001` can be hard-deleted once comfortable
  there's nothing left to recover from it; not time-sensitive given the
  free space available.

## References
- [`HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md`](HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md) and the rest of this session's blue-green report series
- PRs #48 (blue-green bootstrap), #49 (staging retirement, repo side)

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session (2026-10-01), continuing directly from the repo-side staging retirement.
