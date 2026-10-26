# TESC Blue-Green Deployment: Adapted Guide for tesc-prod

**Date:** 2026-10-26
**Project:** TESC
**Type:** Architecture Decision / Implementation Plan
**Status:** Plan complete, implementation not yet started on `tesc-prod`

## Summary
TESC asked to set up blue-green deployment on the production VM
(`10.50.200.35`), guided by `HBEC-2026-10-26-blue-green-production-reference-
guide.md`. This report adapts that pattern to TESC's real (not aspirational)
topology and transfer mechanism, corrects a registry-model mismatch found in
TESC's own pre-existing draft scaffold (see companion bug log in
References), and lays out the concrete implementation plan: compose
structure, the tar-based image-activation step, the nginx atomic-cutover
mechanism, and which guardrails from the HBEC pattern TESC already has vs.
still needs.

## Context / Trigger
Explicit user request: "set up blue-green deployment in the deployment VM in
tesc-prod, guided by a blue-green deployment md file in software-engineer
repo." No TESC-specific guide existed. The closest prior art was
`HBEC-2026-10-26-blue-green-production-reference-guide.md` (same author
pattern, proven live in a real production system) and TESC's own engineering
guide `10. Deployment And Maintenance.md` (stack-agnostic self-hosted-VPS
patterns, lists TESC as high-fit). The user confirmed via
`AskUserQuestion`: adapt the HBEC guide.

## Scope
**In scope:** designing the blue-green topology for `tesc-prod` only (the
staging VM's role as pre-flight verification environment is unchanged — see
Decisions §1), the image-activation mechanism adapted to TESC's real
tar-transfer/no-registry-pull policy, the nginx atomic-cutover mechanism, and
a gap list of guardrails TESC needs vs. already has.

**Out of scope:** actually running this on `tesc-prod` (that's the next,
separate step once this plan is reviewed), re-architecting the staging VM,
and the GitHub Actions pipeline (confirmed unadopted — not part of the real
process either before or after this change).

## Method
Read, in order: the HBEC reference guide (the pattern being adapted); TESC's
own draft blue-green scaffold already committed (`f8646b4`, `198c706` —
`docker-compose.bluegreen.yml`, `scripts/bluegreen-{deploy,cutover}.sh`,
`scripts/bluegreen.py`, `scripts/verify_expand_contract.py`,
`tests/test_bluegreen_deployment.py`); TESC's real, currently-followed
deployment process (`project_docs/04-infrastructure-and-cicd.md`,
`project_docs/09-deployment-and-operations.md`, `DEPLOYMENT.md`); and the
live `docker-compose.prod.yml` / `nginx/nginx.conf` actually in use. Found
and logged one real mismatch along the way (see References) before writing
this plan, rather than building the plan on top of the unverified draft.

## Decisions & Findings

### 1. Staging VM's role is unchanged; blue-green is a prod-VM-internal mechanism
TESC already has a staging VM (`10.50.1.37`) used for build + full smoke-test
verification before anything reaches prod. HBEC's pattern *repurposes* its
`staging-*` subdomains to mean "whichever color is currently inactive" on
the same production host. TESC should **not** collapse these two concepts:
the staging VM stays exactly what it is today (pre-flight environment,
`project_docs/08`), and blue-green is purely a `tesc-prod`-internal mechanism
that replaces steps 6–9 of the current runbook (`09`) — the part that
currently causes real downtime (`docker compose up -d --no-deps backend
celery-worker` + `docker restart nginx`) — with deploy-to-idle-color,
verify, then one atomic nginx reload. Nothing about how staging validates a
build changes.

### 2. Topology: two colors of the four app services, db/redis stay singleton
Following the real services actually running on `tesc-prod`
(`project_docs/04`, not the aspirational three-image GHCR model):

```
tesc-prod (10.50.200.35)
  nginx (single entrypoint, :80/:443) — the only thing that ever changes
    which color it points at
  backend_blue / backend_green            (tesc-backend image)
  celery-worker_blue / celery-worker_green (same image, different command)
  frontend-client-v2_blue / _green         (tesc-main image)
  frontend-admin-v2_blue / _green          (tesc-inst image)
  db (postgres)   — one, shared by both colors, always
  redis           — one, shared by both colors, always
```

This matches HBEC's "shared stateful singletons, duplicated stateless app
tier" split exactly (HBEC guide §1) — TESC has no per-pillar worker/beat
singleton-follows-active-color complexity to replicate since TESC's only
background service is the one `celery-worker`, which gets its own blue/green
pair like the rest of the app tier rather than a follow-the-active-color
singleton (TESC has no GPU-bound or otherwise unduplicable worker).

### 3. Image activation: tar-transfer, not registry-pull — the real fix
This is the one place the existing draft scaffold must change (see
companion bug log). TESC's actual, deliberate policy is: build only on
staging, transfer via `.tar`/SFTP, prod never builds or pulls
(`project_docs/04` §"Build once, deploy everywhere"). Blue-green doesn't
change this policy — it just changes *which* running color a transferred
image lands on:

- Staging still builds and tags images, now by **immutable short SHA**
  (`tinotenda762/tesc-backend:sha-<7char>`) instead of `:latest` — this is
  the one real behavior change on staging, and it's required: a mutable
  `:latest` tag can't distinguish "what blue is running" from "what green is
  running" once both exist at once.
- `docker save tinotenda762/tesc-backend:sha-<7char> -o tesc-backend.tar` →
  SFTP to prod → `docker load` on prod, exactly as today (`09` §5).
- The **new** step: after loading, tag the loaded image locally as whichever
  color is currently idle's image (`docker tag tinotenda762/tesc-backend:
  sha-<7char> tesc-backend:<idle-color>`), so the idle color's compose
  service (pinned to `tesc-backend:${target_color}` as a local-only tag, no
  registry involved) picks it up on `up -d --no-deps`. No `docker compose
  pull` anywhere in the prod path, ever.
- `.sha_blue` / `.sha_green` marker files (HBEC guide §5, already present as
  a single `active_color` file in TESC's draft — needs a sibling per-color
  SHA marker) record which SHA each color is running, written only by a
  dedicated script, never hand-edited — same reasoning as HBEC: a stale or
  malformed marker must be a loud failure, not a silent wrong-image load.

### 4. Migration gate: already built, keep as-is
`scripts/verify_expand_contract.py` (from `198c706`) already implements the
HBEC pattern's §6 exactly — AST-inspects Django migrations for
`RemoveField`/`DeleteModel`/`RenameField`/`RenameModel`/non-nullable
`AlterField`/destructive raw SQL, fail-closed, requires an explicit base
revision. This is good and needs no change. One addition worth making:
TESC's real runbook (`09` §2) already has a *separate*, more thorough
practice — dry-running pending migrations against a scratch DB restored from
a real prod backup — which is a stronger check than AST inspection alone
catches (it caught a real production-breaking migration before, per
`project_docs/10`). **Keep both**: the AST gate as the fast, mechanical,
always-on check; the scratch-DB dry-run as the deliberate, human-run step
before any deploy that touches schema. Neither replaces the other.

### 5. nginx atomic cutover: fix the directory-mount trap before it bites
TESC's current prod `nginx/nginx.conf` already independently discovered and
documented half of HBEC guide §9's lesson — the comment block in
`nginx/nginx.conf` (lines 24–35) explains exactly why upstreams are
referenced through `set $upstream ...; proxy_pass $upstream;` variables
instead of bare `proxy_pass http://service:port`: Docker's embedded DNS
resolves a bare hostname once and caches it, stranding nginx on a stale IP
after a container recreate. This is the *DNS-caching* half of the problem
and TESC already has the fix.

The *other* half — **the bind-mount trap** — is not yet addressed. TESC's
`docker-compose.prod.yml` mounts the single file
`./nginx/nginx.conf:/etc/nginx/nginx.conf:ro`. HBEC hit this exact failure
mode on an isolated dry run: a single-file bind mount stays pinned to the
old inode after an in-place rewrite (`render_bluegreen_nginx.py` writing a
new file to the same path, which most editors/scripts do via rename-over or
truncate-and-rewrite), so the container can keep serving stale routing with
no visible error. **Fix before relying on `render_bluegreen_nginx.py` for
real cutovers**: mount the `nginx/` *directory*, not the single file, exactly
as HBEC's guide prescribes (§9).

TESC's draft `bluegreen-cutover.sh` already does the right sequence
otherwise: render → `nginx -t` (validate before applying) → `nginx -s
reload` → only then write `active_color`. That ordering matches HBEC §9's
"write the marker only after the reload has already succeeded" rule exactly
and should be kept unchanged.

### 6. Gap list — guardrails HBEC's live system has that TESC's draft doesn't yet
Comparing against the HBEC guide's §2, §5, §7, §8 one-for-one:

| HBEC guardrail | TESC equivalent | Status |
|---|---|---|
| `check-compose-colors.py` (no colored service points at unsuffixed/wrong-color host) | — | **Missing.** Needed: TESC's compose anchors are simple enough (4 app services, 2 colors) that this can be a short script checking each `*_blue`/`*_green` service's `DB_HOST`/`REDIS_URL` env resolve to the shared singletons, never to the other color. |
| `record-color-sha.sh` (sole marker writer, rejects non-7-char-hex) | — | **Missing.** `active_color` file exists; no per-color SHA marker or writer yet (needed per §3 above). |
| `verify-revisions.sh` (proves the *running* container is on the expected SHA, not just "healthy") | — | **Missing.** TESC's `09` §7 already does an ad-hoc version of this manually ("verify backend health... prefer a real functional check") — worth scripting the same way HBEC did, scoped to the compose project so it can't false-match an unrelated stack on the same host. |
| `verify-service-links.sh` (real signed call between services, not just "booted") | TESC has no inter-service HMAC-signed call pattern like HBEC's — backend/celery-worker/frontend all share one DB, no cross-service API calls to verify | **Not applicable** in the same form; TESC's equivalent risk is "frontend built against a stale API contract," which a smoke-test hit against the idle color's exposed-for-staging-check port covers better than a service-link check would. |
| `preflight-secrets.sh` (no missing/shared/default secrets) | — | **Missing, and worth adding regardless of blue-green**: TESC already has `scripts/reencrypt.sh` and `scripts/rotate-key.sh` touching `ENCRYPTION_KEY`/`SECRET_KEY`; a cheap preflight that checks these aren't empty, aren't a documented bootstrap default, and are identical between whichever `.env` prod is about to use is straightforward to add and catches the same class of silent-forgery risk HBEC's version does. |
| `check_runtime_secret_drift.py` | — | **Missing**, same rationale as above — lower priority than the compose-color and SHA-marker checks since it's about rotation hygiene, not the blue-green mechanism itself. |

## Changes Made (this session)
- No code changes to the TESC repo yet — this is the plan. Wrote the
  companion bug-log entry documenting the registry-model mismatch found in
  the existing draft scaffold (see References) so it isn't silently carried
  forward into the real implementation.

## Verification
N/A — planning only. The implementation step (updating
`docker-compose.bluegreen.yml`'s image references and activation
mechanism, fixing the nginx directory-mount, adding the compose-color and
SHA-marker guardrail scripts, then a real dry-run deploy-and-cutover cycle
on `tesc-prod` against a low-risk commit) is the next piece of work, to be
verified the same way HBEC's was: a real deploy-and-cutover, not just unit
tests of the renderer.

## Follow-ups / Deferred
1. **Implement the tar-transfer activation step** (§3) — update
   `scripts/bluegreen-deploy.sh` to load+locally-retag instead of `docker
   compose up --wait` against a registry tag it can't reach.
2. **Fix the nginx bind-mount** (§5) before the first real cutover —
   mount `nginx/` as a directory in `docker-compose.bluegreen.yml`.
3. **Add `check-compose-colors.py` and `record-color-sha.sh`** (§6),
   scoped down to TESC's 4-service/2-color topology — much smaller than
   HBEC's 9-service version.
4. **Add the per-color SHA marker files** alongside the existing
   `active_color` file.
5. Once 1–4 are done: a real first deploy-and-cutover dry run on
   `tesc-prod`, the same way the HBEC guide's own Verification section
   describes — as the actual proof this plan works, not just that it reads
   plausibly.
6. `preflight-secrets.sh` / `check_runtime_secret_drift.py` — useful but
   independent of the blue-green mechanism itself; can land after the core
   cutover path is proven.

## References
- `reports/HBEC-2026-10-26-blue-green-production-reference-guide.md` — the
  pattern this plan adapts.
- `DevOps_and_Infrastructure/TESC-2026-10-26-bluegreen-scaffold-registry-mismatch.md`
  — the specific drift this plan corrects.
- TESC repo: `project_docs/04-infrastructure-and-cicd.md`,
  `project_docs/09-deployment-and-operations.md`, `DEPLOYMENT.md`,
  `docker-compose.bluegreen.yml`, `scripts/bluegreen-deploy.sh`,
  `scripts/bluegreen-cutover.sh`, `scripts/bluegreen.py`,
  `scripts/verify_expand_contract.py`, `nginx/nginx.conf`.
- Engineering guide `10. Deployment And Maintenance.md` — general
  self-hosted-VPS pattern (lists TESC as high-fit); this plan is the
  TESC-specific instantiation of it, cross-pollinated with the live HBEC
  implementation.

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~1 session (planning only; implementation is follow-up work)
