# PROBITAS (AgriCredit) — Memory Index

**Last updated:** 2026-11-23
**Project repo:** /home/shadowe/Projects/ProbitasCo (GitHub: restk-solutions/ProbitasCo, local `origin` remote is stale and still points at winstonjthinker/ProbitasCo)
**One-line what-it-is:** Agricultural input distribution + farmer credit platform for Tongaat sugarcane growers. Django+DRF+Celery+Postgres backend, React+Vite web frontend, React Native field app (offline).

Read this file first, every session, before touching the codebase. If
something here is stale or wrong, fix it in the same session you notice.

## What this project is
Monorepo: `/backend` (Django+DRF+Celery+Postgres), `/frontend/web`
(React+Vite), `/frontend/field` (React Native, offline), `/infra`, `/docs`.
Business logic lives only in `apps/*/services/`; ledger/event tables are
insert-only (reverse-and-replace, never UPDATE/DELETE); money is always
Decimal+currency. See the project's own `CLAUDE.md` for the full
non-negotiable architecture rules — don't duplicate them here.

## Current state
- App: slice-based development, up to "Slice 22" as of 2026-11-23 (web
  design follows mockups; frame, approvals, schedule, remittance, grower
  screens). No production deploy has ever existed before this.
- Deploy infra: added 2026-11-23 (see
  `SOFTWARE-ENGINEER/reports/PROBITAS-2026-11-23-blue-green-deploy-pipeline.md`).
  Repo-side files only — `.github/workflows/deploy.yml`,
  `ops/deploy/{deploy-color.sh,cutover.sh,docker-compose.production.yml}`,
  `docs/deploy/RUNBOOK.md`, plus a new `infra/docker/frontend.Dockerfile`
  and a `prod` target added to the existing `infra/docker/backend.Dockerfile`.
  Mirrors hbcaClassroom's proven blue/green pipeline on the same shared VPS
  (`hbca-vps`, 209.209.42.142). **None of the one-time VPS/DNS/GitHub-
  Environment setup has been done yet** — see that report and
  `docs/deploy/RUNBOOK.md`'s "One-time setup" section for the full
  outstanding list (runner registration, project dir, `.env.production`,
  GitHub `production-cutover` environment, DNS, HBEC Caddyfile patch).
- Health endpoint already existed before this work:
  `GET /api/v1/health/` (`apps/core/views.py::HealthView`) — checks DB
  only (`SELECT 1`), does not check Redis or Celery.
- No CI workflow (`.github/workflows/ci.yml`) exists yet — `make verify`/
  `make test`/`make lint` are the mandatory local/pre-PR gate per
  `CLAUDE.md`, but nothing runs them automatically on push/PR yet.
- Celery is used (worker queues: `default,imports,integrations,notifications`;
  `CELERY_BEAT_SCHEDULE` has one periodic task, Zoho retry-due postings
  every 5 min) but **no Celery Beat process is run anywhere**, dev or
  prod — the scheduled task never fires. Flagged as a gap, not fixed.

## Map
- `architecture/` — not yet populated beyond what's in this file; the
  project's own `docs/data-model.md`, `docs/request-flows.md`,
  `docs/api-contract.md` are the real architecture source of truth and
  should be read directly rather than mirrored here.
- `decisions/` — not yet populated.
- `implementation/` — not yet populated.
- `prompts/significant-tasks.md` — not yet populated.
- `change-history/2026-11-23-deploy-pipeline.md` — the deploy pipeline
  addition described above.

## Known gaps / don't trust this for
This memory folder was created in the same session as the deploy pipeline
work and has not yet been filled in from a full read of the application
code (business logic, data model, request flows) — only from what that
session touched (deploy/infra, settings, health endpoint, Celery config,
frontend build). Treat the "Current state" section above as accurate for
deploy/ops topics and verify against code/docs for anything else.

## Related
- Bug/issue log entries for this project: see `SOFTWARE-ENGINEER`
  technical-area folders, filename prefix `PROBITAS-`.
- Reports: see `SOFTWARE-ENGINEER/reports/`, filename prefix `PROBITAS-`.
