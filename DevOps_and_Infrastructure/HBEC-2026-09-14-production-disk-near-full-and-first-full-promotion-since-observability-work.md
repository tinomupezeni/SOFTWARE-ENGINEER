# Production Disk Was at 85% (Docker Build Cache + Untended Image Retention) — Cleaned Up, Then Promoted Today's Work

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
User flagged production as now serving real students and asked for a
housekeeping/migration check before the next promotion. Found
`hbca-vps`'s root filesystem at 85% used (33GB free of 219GB) — Docker's
build cache alone was 79GB (53GB reclaimable), and each of the 9 canonical
service images had 58-68 tagged versions retained instead of the intended
keep-N policy (`scripts/deploy/image-tags.sh prune`, default 5). Cleaned
both, then promoted today's session work (Model Settings dedup/health/
charts, the student-app PWA-banner removal, and 3 pre-existing typecheck
fixes) to production for the first time since this session's observability
work began — previously everything had only reached staging.

## Symptoms
- No user-visible symptom yet — caught proactively via `df -h` /
  `docker system df` before it became an outage. On a host this close to
  full, a routine build, a Postgres WAL write, or a log burst could have
  failed outright.
- Each canonical image (`hbec-student-backend`, `hbec-admin-backend`, etc.)
  had 58-68 `sha-*` tags — `docker system df` showed 565 total images.

## Environment Details
- **Server/Host:** hbca-vps (same physical host serves both `/opt/hbec`
  production and `/home/winstontino/HBEC` staging — one shared Docker
  daemon and image store)
- **Services Affected:** None yet at the time of discovery; disk exhaustion
  would have affected every container on the host
- **Time First Observed:** 2026-09-14

## Investigation Steps

### 1. Initial Diagnosis
```bash
df -h /                 # 178G used, 33G avail, 85%
docker system df        # Images: 565 total, 71.75GB, 15.15GB reclaimable
                         # Build Cache: 770 entries, 78.93GB, 53.04GB reclaimable
```

### 2. Root Cause Analysis
```bash
docker images --format '{{.Repository}}' | grep hbec- | sort | uniq -c | sort -rn
#  68 hbec-admin-backend
#  63 hbec-student-backend
#  62 hbec-student-frontend
#  ... (58-68 each, across all 9 canonical images)
```
`scripts/deploy/image-tags.sh prune 5` exists specifically to keep this
bounded and is called at the end of `cd.yml`'s staging deploy job — but
evidently hadn't been effectively keeping pace, and there's no equivalent
prune step after `deploy-production`, so production's own image list grew
unchecked in parallel.

### 3. Key Findings
- Build cache, not tagged images, was the single largest reclaimable chunk
  (53GB vs ~15GB) — a plain `docker builder prune` most of the way there
  before touching any tagged image at all.
- `image-tags.sh prune`'s design is safe to run without extra care: it
  filters to `sha-*` tags only, groups by image ID, and calls plain
  `docker rmi` (no `--force`) — Docker itself refuses to remove an image
  still backing a running or stopped container, so it cannot touch
  anything live.
- Found 6 unreferenced `hbec-prod/*:current` images (~2.6GB, dated
  2026-09-08, not backing any container) of unknown provenance — left
  untouched pending the user's call rather than guessing they're safe to
  delete.
- Production's `.env` already had real values for `GROQ_API_KEY`,
  `GOOGLE_API_KEY`/`_2`/`_3`, and `OLLAMA_GPU_TUNNEL_URL` — none of these
  were wired into `/opt/hbec/docker-compose.production.yml`'s `harness`
  service block yet (same class of drift as every other production-compose
  finding this session). `MODEL_SETTINGS_ENCRYPTION_KEY`, referenced by
  the git-tracked compose file's newer admin-backend block, is genuinely
  **not** set in production's `.env` at all — left that specific
  larger drift untouched rather than either inventing a new value (which
  would orphan any already-encrypted admin-managed API key) or blocking
  this promotion on an unrelated pre-existing gap.

## Root Cause
Two independent, compounding causes: (1) no scheduled or post-deploy prune
ever ran against production's image store, and staging's own prune
(`image-tags.sh prune 5`, called from `cd.yml`) evidently wasn't keeping
the *shared* host's overall count down either since both environments'
images live in the same local Docker image cache; (2) Docker's build
cache has no automatic eviction policy under this daemon's default
config, so 53GB of no-longer-referenced build layers accumulated
silently.

## Prevention / Rule
**Guardrail:** Add a scheduled (weekly, cron or a CI step) `docker builder
prune -f --filter until=168h` and `scripts/deploy/image-tags.sh prune 7`
run directly on `hbca-vps`, independent of any single deploy job — since
both prod and staging share one image store on one host, pruning needs to
happen at the host level, not only as an afterthought of the staging
deploy pipeline. Alerting on disk usage (e.g. a Prometheus `node_exporter`
filesystem-free-space alert, if `node_exporter` is ever added — currently
absent from this stack, see the `monitoring` profile survey earlier this
session) would also have caught this proactively rather than needing a
manual `df -h` check prompted by an unrelated conversation.

This closes the gap because the actual failure mode is structural:
nothing on this host currently owns "keep disk usage bounded" as a
standing responsibility — it was previously only ever addressed as a side
effect of a staging deploy, which doesn't run often enough or scope wide
enough to catch host-level accumulation shared with production.

## Solution

### Immediate Fix
```bash
docker builder prune -f                        # 53GB reclaimed
scripts/deploy/image-tags.sh prune 7            # 565 -> 132 images, 71.75GB -> 58.59GB
```
Disk went from 85% used (33GB free) to 60% used (86GB free).

Then promoted today's session work to production for the first time:
tagged the already-built `:latest` images for `admin-backend`,
`admin-frontend`, `harness`, and `student-frontend` as `sha-1cefa16`
(matching the real git HEAD those builds correspond to), hand-patched
`/opt/hbec/docker-compose.production.yml` with the two minimal additions
today's work actually needs (the `litellm_config.yaml` read-only mount for
`admin-backend`'s new routing-graph view; the provider-health env vars
for `harness`, all backed by real values already in `.env`), and
recreated `admin-backend`, `admin-frontend`, `admin-worker`, `admin-beat`,
`harness`, and `student-frontend` with `--force-recreate`.

Verified live: Django migrations `model_settings.0005`/`0006` ran
automatically and collapsed 7 real duplicate `ModelAdapter` rows that had
accumulated on production's own database; the harness's new self-hosted
reachability check correctly detected the same real ZCHPC GPU tunnel
outage found earlier this session (`gpu/qwen14b`/`ollama/llama3.2:3b`
report `down`, `cpu-3b` reports `healthy`); the PWA install banner is
confirmed gone from the served bundle; the new Model Settings routing-flow
UI is confirmed present in the admin frontend bundle.

### Long-term Fix
Schedule the periodic prune described in the Guardrail above; decide
whether to remove the 6 orphaned `hbec-prod/*:current` images; separately
decide whether to provision `MODEL_SETTINGS_ENCRYPTION_KEY` on production
(still open, unrelated to this promotion) and finish deploying the
still-deferred Vision (Gemini) pool to production's `litellm_config.yaml`
(confirmed still absent — `vision/gemini-flash` doesn't appear in
production's `ModelAdapter` list post-promotion, consistent with the
already-logged, already-known drift).

## Prevention
- [ ] Configuration changes needed — a scheduled host-level prune (see
      Guardrail)
- [ ] Monitoring/alerts to add — disk-free-space alerting
- [ ] Documentation to update — note in the deploy runbook that prod and
      staging share one image store and one disk on `hbca-vps`
- [x] Code changes required — none; this was operational, not a code fix

## Related Issues
- `HBEC-2026-09-13-production-litellm-config-drift-from-git.md` — same
  general "production compose/config silently behind git" pattern; this
  entry's hand-patches (litellm_config.yaml mount, harness provider-health
  env vars) are two more instances of that same class of drift, now
  closed for these two specific additions.
- `HBEC-2026-09-13-admin-backend-litellm-prometheus-env-missing.md`
  (Antigravity) — claimed production was fixed for `MODEL_SETTINGS_ENCRYPTION_KEY`/
  `LITELLM_URL` defaults; this session's diff against the *actual* live
  `/opt/hbec/docker-compose.production.yml` shows that fix never actually
  landed on production's compose file. Worth a follow-up to reconcile —
  not investigated further here since it's orthogonal to today's
  promotion and touches a hard-required env var with no safe default to
  guess.

## References
- `scripts/deploy/image-tags.sh`
- `/opt/hbec/docker-compose.production.yml` (hand-patched; backed up first
  as `.bak-20260914-070934`)
- `.github/workflows/cd.yml`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery
