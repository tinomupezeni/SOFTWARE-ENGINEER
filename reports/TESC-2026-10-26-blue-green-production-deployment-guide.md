# TESC Blue-Green Deployment: Adapted Guide for tesc-prod

**Date:** 2026-10-26
**Project:** TESC
**Type:** Architecture Decision / Implementation Plan
**Status:** Scaffold implemented and tested (TESC `staging` commit
`3dcc769`); day-zero cutover on `tesc-prod` not yet executed (deliberately
gated on explicit confirmation — see Follow-ups)

## Summary
TESC asked to set up blue-green deployment on the production VM
(`10.50.200.35`), guided by `HBEC-2026-10-26-blue-green-production-reference-
guide.md`, with two explicit constraints: the tesc-staging VM is being
retired to backup-only once this is live (so it can no longer be the build
host), and the setup itself must never drop the currently-running prod
version if there's live traffic. This report adapts the HBEC pattern to
TESC's real topology (verified live via SSH, not assumed from docs — see
Method), corrects two real drifts found along the way (a registry-model
mismatch in TESC's own pre-existing draft scaffold, and unrelated
uncommitted fixes/regressions already live on `tesc-prod` — see companion
bug logs in References), and lays out the implemented design: compose
structure, the build-on-idle-color image-activation step, the nginx
atomic-cutover mechanism, the guardrails TESC now has, and the day-zero
zero-disruption migration runbook for the one-time cutover from today's
single-color deployment.

## Context / Trigger
Explicit user request: "set up blue-green deployment in the deployment VM in
tesc-prod, guided by a blue-green deployment md file in software-engineer
repo." No TESC-specific guide existed. The closest prior art was
`HBEC-2026-10-26-blue-green-production-reference-guide.md` (same author
pattern, proven live in a real production system) and TESC's own engineering
guide `10. Deployment And Maintenance.md` (stack-agnostic self-hosted-VPS
patterns, lists TESC as high-fit). The user confirmed via
`AskUserQuestion`: adapt the HBEC guide. The user then added two concrete
constraints mid-session: (1) blue-green lives entirely on `tesc-prod` itself
— the separate `tesc-staging` VM (`10.50.1.37`) is being retired to
backup-only once this is set up, so images must build directly on
`tesc-prod`'s idle color (confirmed via a second `AskUserQuestion`, an
explicit, documented reversal of the previous "prod never builds" policy);
(2) the setup must never drop the currently-running prod version while
there's live traffic — only one atomic nginx reload may ever move traffic,
and only after the replacement is independently verified healthy.

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
`tests/test_bluegreen_deployment.py`); TESC's documented deployment process
(`project_docs/04-infrastructure-and-cicd.md`,
`project_docs/09-deployment-and-operations.md`, `DEPLOYMENT.md`); and then,
critically, **the real running state of `tesc-prod` itself via SSH** —
`docker ps`, `docker network ls`, `git status`/`git diff` in the real
checkout (`/home/user/Documents/TESC-main`) — rather than trusting any of
the above documents as current. This surfaced three real discrepancies
before a line of blue-green code was written against wrong assumptions:

1. The documented `docker-compose.prod.yml` is retired
   (`docker-compose.prod.yml.retired` sits next to it); the actually-running
   file is the root `docker-compose.yml`, with different service names
   (`backend`, `celery-worker`, `frontend-client-v2`, `frontend-admin-v2`,
   compose project `tesc-main`) than either `docker-compose.prod.yml` or the
   draft blue-green scaffold assumed.
2. `~/deploy_pipeline.sh` on the VM (a stale leftover, confirmed with the
   user — not the live process) builds everything directly on `tesc-prod`;
   the actually-current process remains the tar-transfer-from-staging one in
   `project_docs/09`, up until this change replaces it per the user's
   build-on-prod decision.
3. `docker-compose.yml` and `nginx/nginx.conf` on `tesc-prod` had real,
   uncommitted local edits diverging from git in both directions (a good
   undocumented fix, and a regression) — see the companion bug log
   `TESC-2026-10-26-prod-uncommitted-nginx-regression-and-redis-url-drop.md`.
   Reconciled and committed before building blue-green on top, per the
   user's explicit confirmation.

## Decisions & Findings

### 1. tesc-staging VM is retired to backup-only; blue-green is entirely a tesc-prod-internal mechanism
Per the user's explicit instruction, this is a deliberate departure from
this report's original draft (which assumed the staging VM would stay the
build/verify host, mirroring HBEC's split). The real pre-existing
`~/deploy_pipeline.sh` on `tesc-prod` turned out to be a stale, unused
leftover anyway — per the user, the actual current process is the
tar-transfer-from-staging one in `project_docs/09`. Going forward, once
blue-green is live, that staging VM does nothing but hold backups; **images
for blue-green build directly on `tesc-prod`, for the idle color only**.
This is a real, explicit policy reversal of "prod never builds"
(`project_docs/04`) — accepted deliberately because keeping a second build
host whose only job was producing a tarball stopped making sense once
blue-green gives `tesc-prod` its own safe place to build and verify before
any traffic moves.

### 2. Topology: two colors of the four real app services, db/redis/nginx stay singleton
Verified live via SSH, not assumed from docs (see Method). Real running
container/service names on `tesc-prod` (compose project `tesc-main`,
network `tesc-main_main_net`):

```
tesc-prod (10.50.200.35)
  nginx (single entrypoint, :80/:443, container tesc-main-nginx-1) —
    the one thing that ever changes which color it points at; never
    duplicated, never managed by the blue-green compose file
  backend-blue / backend-green                     (built from ./backend)
  celery-worker-blue / celery-worker-green         (same image, different command)
  frontend-client-v2-blue / -green                 (built from ./frontend)
  frontend-admin-v2-blue / -green                  (built from ./inst)
  db (postgres)   — one, shared by both colors, always, unchanged
  redis           — one, shared by both colors, always, unchanged
```

`docker-compose.bluegreen.yml` only defines the 8 colored app services; it
joins the existing `tesc-main_main_net` network as `external: true` and
never redefines `db`/`redis`/`nginx` — those stay exactly as
`docker-compose.yml` already manages them. This matches HBEC's "shared
stateful singletons, duplicated stateless app tier" split (HBEC guide §1).
TESC has no per-pillar worker/beat singleton-follows-active-color
complexity to replicate — its one background service, `celery-worker`, gets
its own blue/green pair like the rest of the app tier (TESC has no
GPU-bound or otherwise unduplicable worker).

### 3. Image activation: build on tesc-prod's idle color, never a registry
This is the one place the existing draft scaffold had to change (see
companion bug log — it assumed a GHCR pull). Implemented in
`scripts/bluegreen-deploy.sh`:

- `IMAGE_TAG` is computed as the 7-char short SHA of whatever commit
  `tesc-prod`'s checkout currently has as `HEAD` (the operator is
  responsible for having already fetched/checked out the commit being
  deployed) — never `:latest`, so "what is blue running" is never
  ambiguous once both colors exist.
- `docker compose -f docker-compose.bluegreen.yml build` builds only the
  target (idle) color's 4 services, from the local checkout, tagged
  `tesc-{backend,main,inst}-{color}:$IMAGE_TAG`. No push, no pull, no
  registry involved anywhere in the path.
- `up -d --no-deps --wait` starts only those same 4 services — the active
  color's containers and the shared `db`/`redis`/`nginx` are never touched
  by this step.
- `scripts/record-color-sha.sh` (new) is the sole writer of `.sha_blue` /
  `.sha_green`, and refuses anything that isn't exactly a 7-char lowercase
  hex string — same reasoning as HBEC §5: a stale or malformed marker must
  be a loud failure, not a silent wrong-image load on the next deploy or
  cutover.

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

### 5. nginx atomic cutover: directory-mount fix implemented
TESC's prod `nginx/nginx.conf` already had the *DNS-caching* half of HBEC
§9's lesson (the `resolver 127.0.0.11` / `set $upstream` pattern) — though
it had been live-regressed out and needed restoring (see companion bug log
`TESC-2026-10-26-prod-uncommitted-nginx-regression-and-redis-url-drop.md`).

The *other* half — **the bind-mount trap** — is now fixed too:
`docker-compose.yml`'s nginx service mounts `./nginx:/etc/nginx:ro` (a
directory) instead of the single file. A single-file bind mount stays
pinned to the old inode after `render_bluegreen_nginx.py` rewrites it in
place on every cutover, serving stale routing with no visible error — the
exact failure HBEC hit on an isolated dry run. `nginx/mime.types` (pulled
verbatim from the live `nginx:alpine` image) was added to the repo so the
directory mount is self-contained — the stock image's `/etc/nginx` has
other files (`fastcgi_params`, `conf.d/`, etc.) TESC's config never
references, so only `mime.types` was actually needed. Verified: `nginx -t`
against the mounted directory passes in a throwaway container, and
`docker compose -f docker-compose.bluegreen.yml config` / `... -f
docker-compose.yml config` both validate cleanly.

`scripts/bluegreen-cutover.sh` keeps the right sequence: verify the target
color's containers are actually `Running` → render → `nginx -t` (validate
before applying) → `docker exec <nginx-container> nginx -s reload` → only
then write `active_color`/`.cutover_from`. nginx itself is never duplicated
or recreated by this file — cutover reconfigures and reloads the one real
`tesc-main-nginx-1` container directly, since nginx is a shared singleton
like `db`/`redis`, not a blue/green pair.

### 6. Gap list — resolved
Comparing against the HBEC guide's §2, §5, §7, §8:

| HBEC guardrail | TESC status |
|---|---|
| `check-compose-colors.py` | **Done** — `scripts/check_compose_colors.py`, scoped to TESC's 4-service/2-color topology: fails if a colored service's `DB_HOST`/`REDIS_URL`/`CELERY_*` env resolves anywhere but the shared `db`/`redis` singletons, or if a service is missing its blue/green pair. |
| `record-color-sha.sh` | **Done** — `scripts/record-color-sha.sh`, sole writer of `.sha_blue`/`.sha_green`, rejects non-7-char-hex. |
| `verify-revisions.sh` | **Deferred** — TESC's `09` §7 already does an ad-hoc manual version ("prefer a real functional check"); a scripted version scoped to the compose project is lower priority than getting the first real cutover proven. |
| `verify-service-links.sh` | **Not applicable** in the same form — TESC's backend/celery-worker/frontend share one DB with no inter-service HMAC-signed calls to verify like HBEC's. |
| `preflight-secrets.sh` / `check_runtime_secret_drift.py` | **Deferred** — useful regardless of blue-green (TESC already has `scripts/reencrypt.sh`/`rotate-key.sh` touching `ENCRYPTION_KEY`/`SECRET_KEY`) but independent of the cutover mechanism itself; can land after the core path is proven live. |

## Changes Made (this session)
- TESC `staging` commit `3dcc769`: rewrote `docker-compose.bluegreen.yml`,
  `scripts/bluegreen-deploy.sh`, `scripts/bluegreen-cutover.sh`,
  `scripts/bluegreen.py` against the real service names/topology; added
  `scripts/check_compose_colors.py`, `scripts/record-color-sha.sh`,
  `nginx/mime.types`; fixed `docker-compose.yml`'s nginx mount to a
  directory; rewrote `tests/test_bluegreen_deployment.py` accordingly.
- TESC `main` commit `e4fbf03` (merged into `staging`): reconciled real,
  uncommitted drift already live on `tesc-prod` — see companion bug log.
- Two SOFTWARE-ENGINEER bug-log entries filed for the two real
  misconfigurations found along the way (see References).

## Verification
- `python3 -m pytest tests/test_bluegreen_deployment.py
  tests/test_expand_contract_gate.py` — 16/16 pass.
- `IMAGE_TAG=test1234 docker compose -f docker-compose.bluegreen.yml config
  --quiet` — no errors.
- `docker run --rm -v "$(pwd)/nginx:/etc/nginx:ro" nginx:alpine nginx -t` —
  syntax OK, confirming the new directory-mount approach.
- A rendered nginx config from `scripts/render_bluegreen_nginx.py` passes
  `nginx -t` in a throwaway container.
- Live on `tesc-prod`: the drift-fix nginx reload was verified end-to-end
  (`nginx -t`, reload, both public domains + `/api/` returning correct
  codes) — see the companion bug log for the exact checks.
- **Not yet done**: an actual blue-green deploy-and-cutover on `tesc-prod`.
  The scaffold is implemented and unit-tested but has not been exercised
  against the real VM end-to-end — that's the day-zero runbook below,
  gated on explicit confirmation before execution.

## Day-Zero Runbook: migrating tesc-prod into blue-green without dropping live traffic
The one constraint that shapes this entire runbook: **the currently-running
unsuffixed containers (`backend`, `celery-worker`, `frontend-client-v2`,
`frontend-admin-v2`) are never stopped, recreated, or touched until after a
new, independently-verified replacement is confirmed healthy and traffic has
already been atomically switched to it.** `db`, `redis`, and `nginx` are
never touched at all during the migration itself — they're the same
containers before and after.

1. **Bootstrap the color marker.** `echo green > active_color` on
   `tesc-prod`. Nothing in this step starts, stops, or reads any container —
   it only makes `bluegreen-deploy.sh` compute "blue" as its target on the
   next step, since "green" doesn't exist yet and never will until the
   *next* deploy after this one.
2. **Build and start "blue" alongside the untouched old stack.**
   `MIGRATION_BASE_SHA=<current running sha, e.g. fcf6985> scripts/
   bluegreen-deploy.sh` — builds the 4 app services from the current
   checkout, tags them `*-blue:<new-sha>`, starts only
   `backend-blue`/`celery-worker-blue`/`frontend-client-v2-blue`/
   `frontend-admin-v2-blue` via `--no-deps`, pointed at the same already-
   running `db`/`redis` over the shared network. The old unsuffixed
   containers and nginx are not referenced by this command at all.
3. **Verify blue independently, with zero DNS changes.** Since nginx isn't
   repointed yet, exercise blue directly over the shared docker network,
   e.g. from the nginx container itself: `docker exec tesc-main-nginx-1 wget
   -qO- http://backend-blue:8000/api/<a known-safe read endpoint>` and
   `... http://frontend-client-v2-blue:80/`. Confirm response codes and
   content match what the old stack currently serves for the same request.
4. **One atomic cutover.** `CONFIRM_CUTOVER=yes scripts/bluegreen-cutover.sh`
   — this is the only moment traffic moves. It re-verifies blue's containers
   are `Running`, renders the new nginx config, validates it (`nginx -t`),
   reloads nginx. An nginx reload does not kill in-flight proxied
   connections; only new connections route to the new upstream, so this is
   not a stop-the-world moment the way a full container recreate is.
5. **Verify production post-cutover** the same way the drift-fix was
   verified this session: `curl -H "Host: tesc.zchpc.ac.zw" ...` and the
   inst domain, both expecting 200, plus a real functional check (not just
   "no errors in the log") against the now-live blue backend.
6. **Burn-in, then retire the old stack explicitly.** Only after blue has
   been stable for an agreed burn-in period, `docker stop backend
   celery-worker frontend-client-v2 frontend-admin-v2` (stopped, not
   removed — keep as the immediate rollback target for a further period
   before removing). From this point forward, "green" is the standby color
   for the *next* deploy, exactly as in steady-state blue-green operation.

Rollback at any point before step 6 is free (the old stack was never
touched). Rollback after step 4 but before step 6 is re-running
`bluegreen-cutover.sh` with the colors reversed — the same mechanism as any
future rollback, since the old stack is still running.

## Follow-ups / Deferred
1. **Execute the day-zero runbook above on `tesc-prod`** — explicitly held
   for a separate confirmation before running, since it's the first real
   build-and-deploy against a live production host under this new
   mechanism, and doubles app-tier container count (and build load) on that
   host during the transition.
2. **Coordinate DNS for `tesc-staging.zchpc.ac.zw` /
   `tesc-inst-staging.zchpc.ac.zw`** to point at `tesc-prod` once the
   `tesc-staging` VM is fully retired — not required for day-zero (the
   inactive color can be verified with a Host-header curl against
   `tesc-prod` directly, with no DNS change), but needed for the
   "staging means inactive color" convention to work through a browser.
3. `verify-revisions.sh`-equivalent, `preflight-secrets.sh` (§6) — useful
   follow-on hardening, independent of the core mechanism.
4. Decide a concrete burn-in duration and old-image retention/pruning policy
   once the first real cutover has happened and there's a real data point
   for how quickly problems would surface.

## References
- `reports/HBEC-2026-10-26-blue-green-production-reference-guide.md` — the
  pattern this plan adapts.
- `DevOps_and_Infrastructure/TESC-2026-10-26-bluegreen-scaffold-registry-mismatch.md`
  — the registry-model drift this plan corrected.
- `DevOps_and_Infrastructure/TESC-2026-10-26-prod-uncommitted-nginx-regression-and-redis-url-drop.md`
  — the separate, unrelated live-drift finding resolved before building on
  top of `tesc-prod`'s real state.
- TESC repo: `project_docs/04-infrastructure-and-cicd.md`,
  `project_docs/09-deployment-and-operations.md`, `DEPLOYMENT.md`,
  `docker-compose.bluegreen.yml`, `docker-compose.yml`,
  `scripts/bluegreen-deploy.sh`, `scripts/bluegreen-cutover.sh`,
  `scripts/bluegreen.py`, `scripts/check_compose_colors.py`,
  `scripts/record-color-sha.sh`, `scripts/verify_expand_contract.py`,
  `nginx/nginx.conf`, `nginx/mime.types`,
  `tests/test_bluegreen_deployment.py`. Commits: `3dcc769` (staging),
  `e4fbf03` (main, merged into staging).
- Engineering guide `10. Deployment And Maintenance.md` — general
  self-hosted-VPS pattern (lists TESC as high-fit); this plan is the
  TESC-specific instantiation of it, cross-pollinated with the live HBEC
  implementation.

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
**Duration:** ~1 session (scaffold implemented and tested; day-zero cutover
on `tesc-prod` deliberately held for a separate confirmation)
