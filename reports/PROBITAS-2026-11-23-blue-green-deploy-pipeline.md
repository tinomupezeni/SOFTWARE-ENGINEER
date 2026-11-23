# Blue/green deploy pipeline for AgriCredit (ProbitasCo) on hbca-vps

**Date:** 2026-11-23
**Project:** PROBITAS (AgriCredit / ProbitasCo)
**Type:** Infrastructure / Deployment pipeline (new)
**Status:** Completed (repo-side only; VPS/DNS/GitHub-Environment setup deliberately deferred to the maintainer)

## Summary
Added a full CI/CD deploy pipeline for ProbitasCo targeting `hbca-vps`
(209.209.42.142), adapted directly from the sibling project hbcaClassroom's
proven blue/green pipeline on the same host and same shared Caddy gateway
(`hbec-gateway`). All work is repo-file authoring — no live VPS, DNS, or
GitHub Environment changes were made, per explicit scope.

## Context / Trigger
User request to add a deploy pipeline mirroring hbcaClassroom's, with
several already-confirmed adaptations (Django/DRF instead of FastAPI,
existing Makefile/compose conventions, image names under the
`restk-solutions` GHCR org, `probitas.hbca.tech` domain).

## Scope
Included: GitHub Actions workflow, deploy/cutover shell scripts, production
compose file, a new frontend Dockerfile (none existed before), a `prod`
build target added to the existing backend Dockerfile, and a runbook.
Excluded (explicitly, per task instructions): touching the live VPS, DNS,
HBEC's shared `render-caddyfile.sh`, or GitHub Environment protection
settings — all documented as one-time steps for a human to perform instead.

## Method
Read hbcaClassroom's four reference files in full
(`deploy.yml`, `deploy-color.sh`, `cutover.sh`,
`docker-compose.production.yml`) plus its `RUNBOOK.md`, which documents
real bugs hit on this exact host (IPv6/IPv4 localhost healthcheck bug,
MinIO Docker Hub discontinuation, shared-daemon prune blast radius,
COLOR/IMAGE_TAG export scoping, YAML colon-space parse bug, missing env
vars crashing startup, missing Caddyfile `/api/*` routes). Each of those
bugs was checked against the ProbitasCo adaptation and avoided by
construction (see Decisions & Findings). Then inspected the actual
ProbitasCo repo (Makefile, `infra/docker/backend.Dockerfile`,
`infra/compose/docker-compose.yml`, Django settings, URL config, frontend
package.json/env handling, `git remote -v`) before writing anything new,
rather than assuming parity with hbcaClassroom's stack.

## Decisions & Findings
- **Health endpoint already exists**: `GET /api/v1/health/`
  (`apps/core/views.py::HealthView`), checking `SELECT 1` against the
  database and returning `503` if unreachable. No gap to flag here — unlike
  hbcaClassroom's first pass, this backend already had one. It does not
  check Redis or Celery; noted as a smaller, non-blocking gap in the
  runbook (worker health is checked independently via its own container
  healthcheck).
- **Backend Dockerfile**: did not need a rewrite — it was already
  effectively prod-shaped (non-root user, gunicorn entrypoint, minimal
  final layer). Added a trivial additive `FROM runtime AS prod` final
  stage so `--target prod` and the existing no-target `make build` path
  produce the identical image, rather than duplicating the Dockerfile.
- **Frontend Dockerfile did not exist at all** — `infra/compose/docker-compose.yml`'s
  dev `web` service runs `vite build`/`vite preview` out of a bind-mounted,
  `npm ci`'d node_modules, which has no production-image equivalent. Wrote
  a new multi-stage `infra/docker/frontend.Dockerfile` (node builder →
  nginx:alpine runtime), with `VITE_API_BASE_URL` as a build ARG (Vite
  inlines `VITE_*` at build time; confirmed via
  `frontend/web/src/app/env.ts` and `.env.example`) baked to
  `https://probitas.hbca.tech/api/v1`. Deliberately used `npm ci
  --include=dev` regardless of `NODE_ENV`, reproducing the fix
  hbcaClassroom's runbook documents for the exact `tsc: not found`
  failure its first build hit.
- **Required-with-no-default env vars**, found by reading
  `config/settings/base.py`/`prod.py` directly rather than guessing:
  `DJANGO_SECRET_KEY`, `DATABASE_URL` (built from `POSTGRES_*`),
  `DJANGO_ALLOWED_HOSTS`, `JWT_SIGNING_KEY`, `CORS_ALLOWED_ORIGINS` (the
  last three have dev-only defaults that are unsafe/unusable in prod, so
  compose enforces them with `:?required` anyway). Four `ZOHO_*` vars and
  a few others have safe blank/numeric defaults and were left optional.
- **Image org**: confirmed via `gh api repos/restk-solutions/ProbitasCo`
  (readable, `admin` permission) that the org move is real, even though
  the local `origin` git remote is stale (`winstonjthinker/ProbitasCo`).
  Flagged as a known gap rather than silently rewritten.
- **GitHub Environment `production-cutover`**: confirmed via
  `gh api repos/restk-solutions/ProbitasCo/environments` (read-only) that
  it does not exist yet. Despite having `admin` permission and the
  technical ability to create it via the API, did **not** create it —
  per explicit task instruction, this is a one-time human decision
  (required reviewer) documented in the runbook instead.
- **Celery Beat gap found during this work**: `CELERY_BEAT_SCHEDULE`
  (Zoho retry-due task, every 5 min) is defined in `config/settings/base.py`
  but no `celery -A config beat` process is run anywhere — not in this new
  production compose file, and not in the existing
  `infra/compose/docker-compose.yml` for local dev either. This is a
  pre-existing gap in the application, not something introduced by this
  pipeline; documented in both the runbook's "Known gaps" and
  `Project_Memory/PROBITAS/MAIN.md`, not silently fixed (adding a `beat`
  service would be a real behavior change outside this task's scope).

## Changes Made (in /home/shadowe/Projects/ProbitasCo)
- `infra/docker/backend.Dockerfile` — added additive `prod` target (no
  behavior change to the default/no-target build).
- `infra/docker/frontend.Dockerfile` (new) + `infra/docker/frontend-nginx.conf` (new).
- `ops/deploy/docker-compose.production.yml` (new) — db/redis as a fixed
  `agricredit-data` singleton project; backend/worker/frontend as the
  per-color `agricredit-${COLOR}` app tier, including a Celery worker
  (queues matching dev: `default,imports,integrations,notifications`).
- `ops/deploy/deploy-color.sh` (new, executable) — Django-adapted: runs
  `manage.py migrate --noinput` as part of the backend container's own
  startup command (folded into its healthcheck gate) rather than a
  separate `alembic`-style step, since Django's migrate is idempotent and
  safe at container start; this also means a bad migration blocks cutover
  the same way any other startup failure would.
- `ops/deploy/cutover.sh` (new, executable) — same structure as
  hbcaClassroom's, renamed container/project identifiers.
- `.github/workflows/deploy.yml` (new) — same two-phase
  (build-and-stage → approve-cutover → cutover) shape, `runs-on:
  [self-hosted, hbca-vps]`, concurrency group `probitas-deploy`.
- `docs/deploy/RUNBOOK.md` (new) — host context, full one-time setup list
  (none of it done yet, unlike hbcaClassroom's runbook which recorded
  already-completed steps), required env var table, Caddyfile patch diff
  for the maintainer to apply by hand, bootstrap sequence, normal flow,
  rollback, known gaps.

Nothing was committed or pushed in ProbitasCo, per task instructions —
left in the working tree for human review.

## Verification
- `make lint` (ruff check/format, lint-imports, ledger-immutability guard)
  — all green, unaffected by these changes.
- `docker build -f infra/docker/backend.Dockerfile --target prod -t
  probitas-backend:prod-test .` — succeeded.
- `docker build -f infra/docker/frontend.Dockerfile --target prod -t
  probitas-frontend:prod-test --build-arg
  VITE_API_BASE_URL=https://probitas.hbca.tech/api/v1 .` — succeeded
  (confirmed `tsc -b && vite build` completes with `--include=dev`).
  Both test images were removed after the build check; nothing was pushed.
- Not verified (cannot be, without the live VPS): actual blue/green
  cutover behavior, the Caddyfile patch, runner registration, or the
  GitHub Environment gate actually blocking.

## Follow-ups / Deferred
- All "One-time setup" steps in `docs/deploy/RUNBOOK.md` remain for the
  maintainer: runner registration (its own, not shared with
  hbcaClassroom's), project directory + `.env.production` on the VPS,
  `production-cutover` GitHub Environment with required reviewer
  `tinomupezeni`, DNS for `probitas.hbca.tech`/`staging-probitas.hbca.tech`,
  and the HBEC `render-caddyfile.sh` patch (diff provided, not applied).
- No PR-time CI workflow (`.github/workflows/ci.yml`) exists yet to gate
  `main` before this deploy workflow trusts it.
- Celery Beat is not run anywhere (pre-existing gap, see above) — the
  Zoho retry-due scheduled task never fires in any environment today.
- `origin` git remote in the local ProbitasCo checkout is stale
  (`winstonjthinker/ProbitasCo` vs. the real `restk-solutions/ProbitasCo`).

## References
- hbcaClassroom's deploy pipeline (reference implementation):
  `/home/shadowe/Projects/hbcaClassroom/.github/workflows/deploy.yml`,
  `ops/deploy/{deploy-color.sh,cutover.sh,docker-compose.production.yml}`,
  `docs/deploy/RUNBOOK.md`.
- `Project_Memory/PROBITAS/MAIN.md` (created this session).

---

**Completed By:** Claude (agent session)
**Duration:** single session, 2026-11-23
