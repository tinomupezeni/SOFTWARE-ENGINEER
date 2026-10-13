# Manual blue-green deploys built only the 9 color-paired images, missing `hbec-harness-ml` (harness-embeddings), briefly stopping all worker/beat singletons during cutover

**Date:** 2026-10-13
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`)
**Severity:** Medium (brief, self-caught outage of background workers; zero student-facing impact since `harness-embeddings` itself hadn't changed)
**Status:** Resolved

## Summary
During today's cutover (flipping live traffic from `blue` to `green`), the
step that recreates the singleton workers/beats to follow the new color
failed partway through: `docker compose ... up` tried to pull
`ghcr.io/rest-creator/hbec-harness-ml:sha-9ae1402` from GHCR (private,
403/unauthorized by design — images are built on the VPS, never pulled),
which aborted the whole batch **after** it had already stopped
`student-worker`, `student-beat`, `admin-worker`, `admin-beat`,
`notifications-worker`, `notifications-beat`. All six sat stopped for a
few minutes until caught and fixed.

## Symptoms
```
Image ghcr.io/rest-creator/hbec-harness-ml:sha-9ae1402 Pulling
Image ghcr.io/rest-creator/hbec-harness-ml:sha-9ae1402 Error error from registry: unauthorized
```
`docker ps -a` immediately after showed all six workers/beats
`Exited (0)` or `Exited (137)`, `harness-embeddings` itself untouched and
still healthy on its old image.

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec`
- **Services Affected:** `student-worker`, `student-beat`, `admin-worker`,
  `admin-beat`, `notifications-worker`, `notifications-beat` (briefly
  stopped); `harness-embeddings` (never actually recreated until the
  follow-up fix)
- **Related Components:** blue-green cutover's singleton-follower handoff
- **Time First Observed:** 2026-10-13T15:38Z (during the day's cutover)

## Investigation Steps

### 1. Initial Diagnosis
The `docker compose ... --profile workers up` command for the followers
printed an image-pull error instead of completing. Checked `docker ps -a`
immediately — confirmed six containers stopped, not restarting.

### 2. Root Cause Analysis
This session's manual replication of `deploy-color` (GitHub Actions isn't
currently triggering for this repo, so every deploy today was done by hand
over SSH) built the 9 color-paired service images each time
(`student-backend`, `student-frontend`, `admin-backend`, `admin-frontend`,
`harness`, `payments`, `schools-backend`, `schools-dashboard`,
`notifications-backend`) but never included `hbec-harness-ml` — the image
`harness-embeddings` actually runs, built from `Dockerfile.ml`. The real
`deploy-color` job in `cd.yml` builds it every time alongside the other 9;
the manual replication simply omitted it across all of today's three prior
deploy cycles. It went unnoticed because `harness-embeddings`' own code
hadn't changed in any of today's commits, so nothing needed it rebuilt
until the cutover step tried to recreate it on the new tag anyway (workers/
beats/`harness-embeddings` all follow `TAG_ACTIVE`, which only changes at
cutover — so this gap was invisible during the three `deploy-color`-only
steps and only surfaced at the one cutover).

### 3. Key Findings
- `docker compose up` with multiple named services evaluates all of them
  before starting any — one missing image aborts the whole invocation,
  even for services whose images already exist locally. This is why six
  *unrelated* containers were stopped by one missing image for a seventh.
- `harness-embeddings` was consequently running stale code (though
  functionally identical, since nothing in it changed today) across all
  three earlier deploy-color cycles this session — a gap that would have
  mattered the first time an actual embeddings-worker change shipped.

## Root Cause
A manual, by-hand replication of an automated pipeline step omitted one of
its ten image builds. The automated job builds all ten unconditionally;
the manual process built only the nine whose services this session
actually needed to deploy, not realizing `harness-embeddings` needed the
same new tag at cutover time regardless of whether its own code changed.

## Prevention / Rule
**Guardrail:** until GitHub Actions is triggering `deploy-color` again for
this repo (a separate, already-flagged gap), any manual replication of a
blue-green deploy must build all 10 images listed in
`scripts/deploy/image-tags.sh`, not just the 9 color-paired ones —
`hbec-harness-ml` specifically, since it's the one non-color-paired image
every cutover's follower step still needs on the new tag. Checking
`scripts/deploy/image-tags.sh exists <sha>` for all ten before touching
`docker compose up` would have caught this before it could stop anything.

Once GitHub Actions is restored, this entire class of gap disappears —
`deploy-color`'s own script already builds unconditionally and in one
place; it cannot "forget" one the way a human replicating it by hand can.

## Solution

### Immediate Fix
```bash
sudo docker build --build-arg GIT_SHA=9ae1402 \
  -t ghcr.io/rest-creator/hbec-harness-ml:sha-9ae1402 \
  -f AGENTIC_HARNESS/Dockerfile.ml ./AGENTIC_HARNESS
# then, once built:
docker compose -f docker-compose.production.yml --profile workers \
  up -d --wait --no-deps harness-embeddings
# and separately, immediately after the image-pull failure:
docker compose -f docker-compose.production.yml --profile workers \
  up -d --wait --no-deps student-worker student-beat admin-worker \
  admin-beat notifications-worker notifications-beat
```
Verified: all 7 followers on `sha-9ae1402` via `verify-revisions.sh`,
zero container restarts anywhere, all public domains `200` throughout and
after.

### Long-term Fix
No code change needed — `scripts/deploy/image-tags.sh`'s own list is
already correct and complete; this was purely a gap in manually
replicating it. Documented here so the next manual replication (if
GitHub Actions is still down) checks the full ten-image list up front.

## Prevention
- [x] Immediate fix applied and verified
- [ ] GitHub Actions `deploy-color` restored (separate, already-tracked
      gap — see `HBEC-2026-10-12-labs-stack-review-merge-deploy.md`'s own
      follow-up note) — the actual permanent fix for this class of error
- [ ] Consider a small pre-flight script for manual replications
      specifically: `image-tags.sh exists <sha>` across all 10 services
      before any `docker compose up`

## Related Issues
- `HBEC-2026-10-12-labs-stack-review-merge-deploy.md` — first flagged
  that GitHub Actions isn't triggering for this repo, which is why manual
  replication has been necessary for every deploy since.

## References
- `scripts/deploy/image-tags.sh` (the authoritative 10-image list)
- `.github/workflows/cd.yml` (`deploy-color`, `cutover` jobs — the
  automated process this session has been manually replicating)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** ~10 minutes (caught immediately via the
post-cutover restart-count check, fixed before any user impact — this
was a backend/background-job gap, not a public-facing outage)
