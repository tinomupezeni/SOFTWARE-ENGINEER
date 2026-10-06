# VPS root disk at 99% full — stale sha-tagged images from manual deploy rounds, no cleanup step

**Date:** 2026-10-06
**Project:** HBEC
**Environment:** Production (`hbca-vps`)
**Severity:** High (near-total disk exhaustion; would eventually break Postgres writes, logging, anything)
**Status:** Resolved (immediate); root cause (no cleanup step in the manual deploy process) still open

## Summary
A routine deploy-to-green (commit `e44223f`, round 5 of today's manual
deploys) failed mid-build with `No space left on device` while downloading
`harness-ml`'s embedding model weights. The VPS root filesystem was at
**99% used (4.0GB free of 219GB)**. `docker system df` showed 241 images
totaling 137.8GB, of which **82.92GB (60%) was reclaimable** — unreferenced
images left behind by five rounds of manual `docker build --build-arg
GIT_SHA=...` deploys today, each producing a full new tagged image set per
service, with nothing ever cleaning up the superseded ones.

## Symptoms
- `docker build` for `hbec-harness-ml:sha-e44223f` failed:
  `RuntimeError: Task error: File reconstruction error: IO Error: No space
  left on device (os error 28)`, inside `huggingface_hub`'s
  `snapshot_download`.
- `df -h /` → `207G used / 219G, 4.0G avail, 99%`.

## Environment Details
- **Server/Host:** `hbca-vps`, `/` (root filesystem, `/dev/sda3`)
- **Services Affected:** none yet at the time of discovery — caught during a
  deploy build, before the disk actually filled completely
- **Related Components:** Docker image/build-cache storage, the manual
  deploy-to-green process (no CD pipeline currently; see CLAUDE.md's
  "GitHub Actions billing is blocked" note)
- **Time First Observed:** 2026-10-06, during deploy round 5

## Investigation Steps

### 1. Initial Diagnosis
The build error named the exact syscall failure (`os error 28`, `ENOSPC`).
Checked `df -h /` immediately — confirmed 99% full, not a transient blip.

### 2. Root Cause Analysis
```bash
docker system df
# Images          241   54   137.8GB   82.92GB (60%)
# Build Cache     115   115  40.38GB   0B
```
Five manual deploy rounds today (`2804d78`, and others before it) each ran
`docker build --build-arg GIT_SHA=<sha> -t <repo>:sha-<sha>` for ~10
services, every round producing a brand-new, fully-tagged image set. The
manual deploy script (`/tmp/deploy_green*.sh`, copied fresh each round) has
no step that removes a superseded round's images once the new one is live —
there is no equivalent of a CI pipeline's automatic image garbage collection.

## Root Cause
The manual deploy-to-green process (standing in for the disabled GitHub
Actions CD pipeline — see CLAUDE.md) accumulates one full image set per
round with no cleanup step, and nothing was watching disk usage until a
build itself failed from it.

## Prevention / Rule
**Guardrail:** add a disk-usage check (or a Prometheus/Grafana alert on
root filesystem usage, per the existing monitoring stack already running on
this VPS) that fires well before 90% — this incident had no warning until a
build failed outright. Additionally, the manual deploy script should prune
images from any round other than the current `.sha_blue`/`.sha_green`
before building (`docker image prune -af` is safe — it only removes images
with zero container references, so it can never touch what's actually
running).

## Solution

### Immediate Fix
```bash
docker builder prune -af   # 40.38GB build cache, zero risk - unattached to any running container
docker image prune -af     # only removes images referenced by no container, running or stopped
# Result: 207G used -> 108G used, 4.0G avail -> 103G avail (99% -> 52%)
```
This also removed the already-built `hbec-harness:sha-e44223f` image from
the failed round (it wasn't yet referenced by any container), requiring a
full rebuild of that round rather than a resume — a one-time cost, not a
new problem.

### Long-term Fix
- Add the disk-usage alert described above.
- Add an image-prune step to the manual deploy script, run *before* each
  round's builds, scoped to images outside the current `.sha_blue`/
  `.sha_green` pair.
- Once the real blue/green CD pipeline (the gated version referenced in the
  open PR #52 title) replaces manual deploys, confirm it includes image
  garbage collection as a pipeline step, not an afterthought.

## Prevention
- [x] Immediate: disk cleared, deploy resumed
- [ ] Monitoring/alert to add: root filesystem usage threshold alert
- [ ] Add automatic image pruning to the manual deploy script
- [ ] Confirm the eventual CD pipeline replacement includes image GC

## Related Issues
- Found mid-deploy while rolling out today's 6 bug fixes (see the 6
  `fix(...)` commits merged this session, and
  `HBEC-2026-10-06-content-replication-embedding-retry-orphaned-rows.md`).

## References
- `docker system df`, `docker image prune`, `docker builder prune`

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Same session as discovery (immediate fix); monitoring/prevention follow-ups remain open.
