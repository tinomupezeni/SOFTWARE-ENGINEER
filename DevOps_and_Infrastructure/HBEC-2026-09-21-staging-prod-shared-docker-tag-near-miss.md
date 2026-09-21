# Staging Build Overwrote Production's `:latest` Docker Tag — Same-Host Namespace Collision

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Production + Staging (hbca-vps, same Docker host)
**Severity:** Critical (near-miss — production was never actually served wrong
code, but the recovery path to the original image was destroyed and had to be
reconstructed under time pressure)
**Status:** Resolved

## Summary
Deploying a routine feature (admin-configurable family subscription plans) to
staging via the documented manual-rebuild flow (`docker compose -f
docker-compose.staging.yml --env-file .env.staging build <service>`)
overwrote the `ghcr.io/rest-creator/hbec-{admin-backend,admin-frontend,
payments,student-backend}:latest` tags in the VPS's **shared local Docker
image store** — the same tags `/opt/hbec/docker-compose.production.yml`
resolves to. `docker-compose.staging.yml`'s `.env.staging` and
`docker-compose.production.yml`'s `.env` both defaulted `TAG=latest`, so
staging and production were never actually isolated from each other on this
host; they only *looked* isolated because nothing had rebuilt staging since
the last production promotion.

The 4 running production containers kept serving correctly throughout (Docker
containers hold their own image layer reference, not a live tag lookup), but
the `:latest` tag itself — the only thing a future recreate, crash-recovery,
or host reboot would resolve — now pointed at untested staging code with no
way back.

## Symptoms
- None user-facing. Caught by the operator (session user) asking "are you
  sure that's safe?" mid-deploy, prompting a check of running-container image
  IDs against the freshly-rebuilt `:latest` tag before continuing.
- Had this gone unnoticed: any prod container recreate (`docker compose up
  -d --force-recreate`, a crash requiring recreation, a host reboot) would
  have silently deployed unreleased, untested feature code to production.

## Environment Details
- **Server/Host:** hbca-vps — single Docker daemon shared by both
  `/opt/hbec` (production, root-owned) and `/home/winstontino/HBEC`
  (staging, owned by `winstontino`)
- **Services Affected:** `hbec-admin-backend`, `hbec-admin-frontend`,
  `hbec-payments`, `hbec-student-backend` (all four rebuilt in this session)
- **Related Components:** `docker-compose.staging.yml` and
  `docker-compose.production.yml` both reference
  `${DOCKER_REGISTRY:-ghcr.io/rest-creator}/hbec-<service>:${TAG:-latest}`;
  `.env` (prod) and `.env.staging` both had `TAG=latest` with no other
  isolation between the two compose projects' image namespace
- **Time First Observed:** 2026-09-21, during the first staging rebuild since
  production's last promotion

## Investigation Steps

### 1. Initial Diagnosis
Ran the documented staging deploy sequence: `git pull --ff-only` in
`/home/winstontino/HBEC`, then `docker compose -f docker-compose.staging.yml
--env-file .env.staging build admin-backend admin-frontend payments
student-backend`. Build succeeded normally — nothing in the build output
itself signals a problem, since `docker compose build` just does what it's
told: build and tag the named image.

### 2. Root Cause Analysis
Compared the running production containers' actual image IDs
(`docker inspect --format='{{.Image}}'`) against what `hbec-*:latest`
currently resolved to in the local store:

```bash
docker inspect --format='{{.Name}} {{.Image}}' $(docker ps --filter name=hbec-admin-backend ... -q)
docker image inspect ghcr.io/rest-creator/hbec-admin-backend:latest --format='{{.Id}}'
```

The IDs did not match — the 4 production containers were running on their
original image, but `:latest` now pointed at the staging build just
produced. Attempted two recovery paths on the original image:
- `docker tag <original-id> ...:latest` — failed, `No such image`: the
  original image record had already been removed from the local store (not
  just re-tagged elsewhere; genuinely gone, not even present as `<none>`
  dangling).
- `docker commit <live-container> ...:latest` — also failed:
  `NotFound: content digest ... not found`. The containerd content store was
  missing blobs for a container that was still running and healthy — the
  running container survives on already-mounted layers, but neither its
  image record nor a fresh commit from it could be reconstructed locally.

With no local recovery path, and GHCR's published `:latest` already
documented elsewhere in this repo as stale since 2026-07-14 (`build-publish.yml`
disabled), the only faithful recovery was rebuilding from source at
production's actually-checked-out commit. `/opt/hbec`'s own git checkout was
confirmed to be pinned at a specific commit (`187ee39e`, not the tip of
`master`) — consistent with this project's documented promotion model
(`cd.yml`'s `deploy-production` job promotes an already-built staging SHA via
`workflow_dispatch`, it doesn't auto-track `main`). `docker-compose.production.yml`
itself is image-only (no `build:` blocks, confirmed via `docker compose build`
→ "No services to build"); the actual build recipe used for prod images
turned out to be a copy of `docker-compose.staging.yml` also present in
`/opt/hbec`, built against `/opt/hbec/.env` so the resulting tag matches what
`docker-compose.production.yml` expects. Rebuilding the 4 services from that
recipe, at that pinned commit, against prod's own `.env`, restored a correct
`:latest` — verified distinct from both the (now-gone) original ID and the
staging build's ID, and confirmed the 4 running containers were untouched and
still healthy throughout (`docker ps` showed unbroken 46h uptime before and
after).

### 3. Key Findings
- Production and staging on this host were never actually isolated at the
  Docker image-tag level — only "looked" isolated because staging hadn't
  been rebuilt since the last time production was promoted. The first
  staging rebuild after any production promotion was always going to hit
  this.
- A production image's local build record and content-store blobs can both
  disappear (via GC or manual pruning history predating this incident) while
  the container built from them keeps running — "the container is still up"
  is not evidence that its image can be reconstructed if the tag is lost.
- `docker-compose.production.yml` being image-only was itself correct and
  by design (per this repo's own `CLAUDE.md`); the exposure was entirely in
  the *shared tag namespace* between it and staging's full build-capable
  compose file, not in the image-only file itself.

## Root Cause
`.env` (production) and `.env.staging` both left `TAG` at its default
(`latest`), and both compose files reference the identical image repository
path (`ghcr.io/rest-creator/hbec-<service>`). With one Docker daemon shared
by both environments, building staging was indistinguishable, at the image
store level, from overwriting production's next-deploy image — nothing in
either compose file or env file said otherwise.

## Prevention / Rule
**Guardrail:** `.env.staging`'s `TAG` must never equal production's `.env`
`TAG` on a shared Docker host. Fixed here by setting `TAG=staging` in
`.env.staging`, so staging now builds and resolves
`ghcr.io/rest-creator/hbec-<service>:staging` — a tag production's compose
file never references — making a repeat of this specific collision
impossible rather than just less likely. Applies only to `.env.staging`;
production's `.env` was left untouched (still `TAG=latest`), since changing
prod's tag convention is a separate decision with its own blast radius and
wasn't necessary to close this gap.

A second-order guardrail worth adding later, flagged but not implemented in
this pass: a pre-build check (script or CI job) that fails loudly if
`TAG` in `.env` and `.env.staging` ever match again, so this can't silently
regress if someone resets `.env.staging` from a template.

## Solution

### Immediate Fix
1. Rebuilt `hbec-admin-backend`, `hbec-admin-frontend`, `hbec-payments`,
   `hbec-student-backend` from `/opt/hbec`'s pinned commit (`187ee39e`)
   against `/opt/hbec/.env`, restoring a correct, current `:latest` —
   verified via image-ID diff that it now differs from both the lost
   original and the staging build, and that running prod containers were
   never touched (uptime unbroken, same image IDs before/after).
2. Set `TAG=staging` in `/home/winstontino/HBEC/.env.staging`.
3. Rebuilt the same 4 services under the new tag
   (`docker compose -f docker-compose.staging.yml --env-file .env.staging
   build ...`), confirmed `ghcr.io/rest-creator/hbec-*:staging` now exists
   and no longer touches `:latest`.
4. Recreated the 4 staging containers (`up -d --no-deps admin-backend
   admin-frontend payments student-backend`) — all healthy, no errors in
   startup logs.

### Long-term Fix
The pre-build `TAG` equality check described above (Prevention / Rule),
implemented as either a Makefile/script guard or a CI check on
`docker-compose.staging.yml` deploys.

## Prevention
- [x] Configuration changes needed — done (`.env.staging` `TAG=staging`)
- [ ] Monitoring/alerts to add — consider alerting if `hbec-*:latest`'s
      image digest changes without a corresponding production deploy event
- [x] Documentation to update — this entry; `HBEC/CLAUDE.md`'s own
      Docker Images section already (correctly) warns about GHCR `:latest`
      being stale, but had nothing about the *local* tag collision risk
      between staging and prod on the same host — worth a follow-up note
      there
- [ ] Code changes required — n/a

## Related Issues
- None found in this repo for same-host staging/prod image-tag collisions.

## References
- `HBEC/docker-compose.production.yml`, `HBEC/docker-compose.staging.yml`
  (`image:` lines using `${TAG:-latest}`)
- `/opt/hbec/.env`, `/home/winstontino/HBEC/.env.staging` (`TAG=`)
- `HBEC/CLAUDE.md` — CI/CD Pipeline section (promotion model,
  `deploy-production` as `workflow_dispatch`-only) and Docker Images (GHCR)
  section (stale `:latest` note)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session, roughly 30 minutes from first noticing
the image-ID mismatch to verified-healthy staging containers on the isolated
tag
