# Deploy script's image prune targeted the whole shared Docker daemon

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps, shared with HBEC/VLabs/ProjectFlow)
**Severity:** High
**Status:** Resolved (caught before first real run)

## Summary
`ops/deploy/deploy-color.sh`'s disk-cleanup step used `docker image prune -af` and `docker builder prune -af`, which act on the entire Docker daemon — not scoped to this project. On `hbca-vps`, that daemon is shared with HBEC, VLabs, and ProjectFlow.

## Symptoms
None manifested yet in production — caught during review of the script itself, before it had run against the shared host for real with other projects' images present in a prunable state.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** potentially any project sharing this Docker daemon (HBEC, VLabs, ProjectFlow)
- **Related Components:** `ops/deploy/deploy-color.sh`
- **Time First Observed:** 2026-11-23, self-review before first live run

## Investigation Steps

### 1. Initial Diagnosis
`docker image prune -a` removes every image with no container currently referencing it, system-wide — not scoped by label, repository, or project in any way `-a` alone provides.

### 2. Root Cause Analysis
The script was modeled on a single-project cleanup pattern without accounting for `hbca-vps` being a shared host with three other active deployments on the same daemon.

### 3. Key Findings
- HBEC's and VLabs' running blue/green containers are themselves safe (an image backing a running container is never pruned), but any of their spare pulled images with no container currently attached would not be.
- `docker builder prune -a` similarly clears the whole daemon's build cache, slowing every other project's next build, not just this one's.

## Root Cause
Treating a shared Docker daemon as if it were dedicated to one project.

## Prevention / Rule
**Guardrail:** On a host running more than one project's containers against one Docker daemon, a deploy script may only blanket-prune resources that are safe regardless of what else is on the host (dangling/untagged layers via `docker image prune -f` with no `-a`, and build-cache entries old enough to be clearly idle via `--filter unused-for=24h`). Anything project-specific (this project's own superseded image tags) must be removed by explicit name, never by a system-wide prune flag.

## Solution

### Immediate Fix
Rewrote the prune step: `docker image prune -f` (dangling only) plus an explicit loop removing this project's own old `ghcr.io/restk-solutions/hbca-classroom-*` tags that aren't the current `.sha_blue`/`.sha_green`; `docker builder prune -f --filter unused-for=24h` instead of `-af`.

### Long-term Fix
None further planned — this is the correct scope for a shared host.

## Prevention
- [x] Configuration changes needed — script rewritten
- [ ] Monitoring/alerts to add
- [x] Documentation to update — `docs/deploy/RUNBOOK.md`, bug log entry
- [x] Code changes required

## Related Issues
- None — caught in isolation during this deploy's build-out.

## References
- `ops/deploy/deploy-color.sh`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~15 minutes
