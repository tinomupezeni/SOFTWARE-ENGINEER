# `.sha_blue` held the full 40-char commit while images were tagged with the short 7-char form, breaking the cutover's worker handoff

**Date:** 2026-10-06
**Project:** HBEC
**Environment:** Production (`hbca-vps`) — during the real blue/green cutover
**Severity:** High (briefly stopped all Celery workers/beats platform-wide during a live cutover)
**Status:** Resolved

## Summary
During the first real production cutover (`active_color` green → blue),
the singleton workers/beats (`student-worker`, `student-beat`,
`admin-worker`, `admin-beat`, `notifications-worker`, `notifications-beat`)
and `harness-embeddings` were stopped as part of the handoff, then failed
to restart: `docker compose up` tried to pull
`ghcr.io/rest-creator/hbec-admin-backend:sha-559b9b679cf30850ec29e29503ef738508457dd2`
(the full 40-character commit hash) from a private registry — `unauthorized`
— because every image actually built and present on the VPS was tagged
with the short 7-character form (`sha-559b9b6`). All 6 Celery
workers/beats were down for several minutes mid-cutover while this was
diagnosed and fixed.

## Symptoms
- `docker compose ... --profile workers up -d --wait --no-deps $FOLLOWERS`
  failed immediately with `Error error from registry: unauthorized`,
  naming an image tag with a 40-character suffix.
- All 6 follower containers (workers + beats) ended up in a stopped state
  (they had already been `stop`ped by the cutover's own handoff step before
  this failure), with no automatic retry.
- Public web/API traffic on the newly-live color was unaffected throughout
  — only background Celery processing stopped.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** `student-worker`, `student-beat`, `admin-worker`,
  `admin-beat`, `notifications-worker`, `notifications-beat`,
  `harness-embeddings` (all down simultaneously, briefly)
- **Related Components:** `/opt/hbec/.sha_blue`, `/opt/hbec/.sha_green`,
  `scripts/deploy/color-env.sh`
- **Time First Observed:** 2026-10-06, during the cutover's follower
  handoff step (the very first time anything read `TAG_ACTIVE` purely from
  the `.sha_blue` file's content, rather than from an explicit
  short-form override argument)

## Investigation Steps

### 1. Initial Diagnosis
`color-env.sh`'s own log line named the exact tag it resolved:
`TAG_ACTIVE=sha-559b9b679cf30850ec29e29503ef738508457dd2`. `docker images`
on the VPS showed every locally-built image tagged `sha-559b9b6` (short),
confirming the mismatch immediately.

### 2. Root Cause Analysis
Across every prior deploy round this session, `.sha_blue` had been
recorded by hand with the **full** `git rev-parse HEAD` output (e.g.
`ad0a5ab9f26b8f0399e2fb43ab006df1b8e1c10c`), while every `docker build`
command used the **short** `git rev-parse --short=7 HEAD` form for its
`-t` tag. This never surfaced before because:
- Every `deploy-color`-style rebuild explicitly passed the short-form tag
  as an override argument to `color-env.sh` (`color-env.sh <live> <new_color>
  sha-<short>`), which bypasses reading `.sha_<new_color>` entirely for the
  color being built.
- `verify-revisions.sh` only compares a running container's baked-in
  `org.opencontainers.image.revision` label (always short-form, from the
  build arg) against a short-form argument — it never reads `.sha_*` files.

The **cutover**'s own follower-handoff step is the first code path in this
session that calls `color-env.sh` with only the *live* color argument (no
override), which derives **both** `TAG_BLUE` and `TAG_GREEN` purely from
file content — the one path that actually depends on the marker files
holding the same format the images were tagged with.

## Root Cause
Two independent pieces of tooling (manual `.sha_*` marker writes, and the
`docker build -t ... sha-<short>` convention) silently disagreed on SHA
length, and no single code path validated them against each other until
the cutover's follower handoff — by which point workers had already been
stopped.

## Prevention / Rule
**Guardrail:** `.sha_blue`/`.sha_green` must always be written with the
**short** (7-character) form, matching `image-tags.sh`'s own `exists`
check and every `docker build -t` invocation. A validating wrapper
(`scripts/deploy/record-color-sha.sh <color> <sha>` that refuses anything
other than exactly 7 hex characters) would close this permanently — right
now nothing stops a 40-character value from being written by hand.

## Solution

### Immediate Fix
```bash
echo "559b9b6" | sudo tee /opt/hbec/.sha_blue
```
Re-ran the FOLLOWERS `up` immediately after; `student-worker`,
`student-beat`, `admin-worker`, `admin-beat` came up clean on the first
retry. `notifications-worker`/`notifications-beat`/`harness-embeddings`
needed two more rounds for unrelated reasons (a separate Redis-failover
override gap — see
`HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md` — and
`harness-ml` never having been built for this exact commit, since it's a
shared singleton outside the per-color image set).

### Long-term Fix
Not yet applied — the validating wrapper proposed above. Until then,
always write `.sha_<color>` with `git rev-parse --short=7 <ref>`, never
`git rev-parse <ref>`.

## Prevention
- [ ] Add `scripts/deploy/record-color-sha.sh` (or similar) that validates
      and is the only sanctioned way to write `.sha_blue`/`.sha_green`
- [ ] Audit `docs/MANUAL_DEPLOY_PROMOTION.md` and any other manual-deploy
      documentation for the same short-vs-full SHA ambiguity

## Related Issues
- `HBEC-2026-10-06-verify-revisions-cross-project-label-collision.md` —
  a different false-positive/fragility class in the same new deploy
  tooling, found the same day.
- `HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md` — the
  second, independent failure hit during the same cutover's follower
  handoff.

## References
- `scripts/deploy/color-env.sh`
- `scripts/deploy/image-tags.sh`
- `.github/workflows/cd.yml` (`cutover` job, follower-handoff step)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** ~10 minutes (diagnosis to all 6 Celery
workers/beats restored); the embeddings/notifications followers took
longer due to the two unrelated issues layered on top.
