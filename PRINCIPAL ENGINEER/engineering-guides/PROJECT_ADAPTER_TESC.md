# PROJECT GUIDE ADAPTER — TESC (ScalarEye)

> Bridge between `dev-logs/PRINCIPAL ENGINEER/engineering-guides/` and the TESC
> (ScalarEye) monorepo. Records which guides were ported, where they landed, and
> the stack adaptations required. Note: TESC already has strong docs
> (`docs/`, `DEPLOYMENT.md`, `IMPLEMENTATION_PLAN.md`) — this adapter reconciles
> them with the guide library rather than duplicating.

## Project

- **Name:** TESC / ScalarEye
- **Path:** `/home/tino/Projects/TESC`
- **Stack:** Django 5.2 + DRF + SimpleJWT (backend, Gunicorn), Postgres 15,
  Redis 7 (cache + Celery broker), Celery workers, nginx reverse proxy, two
  React/Vite frontends (`frontend` public portal, `inst` institution/admin),
  GitHub Actions → self-hosted runner on ZCHPC VM (no inbound). Crypto: Fernet
  (`crypto.py`, `decrypt_search.py`) for searchable encrypted fields.
- **Deploys to:** Self-hosted ZCHPC VM via docker-compose + GH Actions.
- **Already has:** `docs/` (backend/frontend/system-overview/database-schema/
  PRODUCTION_ARCHITECTURE), `DEPLOYMENT.md`, `IMPLEMENTATION_PLAN.md`,
  `tests/` (smoke/functional/integration/regression/load/security/fuzz),
  hardened `docker-compose.prod.yml` with isolated `internal_net`.

## Guides applied

### 6. Database Engineering  → fit: high
- **Ported sections:** UUIDv7 PK standard; short-transaction rule (no external
  calls inside tx — critical for Celery/Fernet crypto paths); migration strategy
  (Django migrations, data port before traffic).
- **Landed in:** `docs/database-schema.md`; `backend/core` models.
- **Adaptation:** Guide assumes SQLAlchemy/Alembic; TESC uses **Django ORM +
  `makemigrations`**. UUIDv7 maps to `django.db.models.UUIDField` (default v4 —
  note the guide prefers v7's chronological clustering if high-volume tables).
- **Compliance:** [x] migrations used (no empty migrations)  [ ] UUIDv7 on new
  high-volume tables  [ ] statement timeouts set on Postgres  [ ] Fernet crypto
  ops kept outside DB transactions

### 10. Deployment And Maintenance  → fit: high
- **Ported sections:** Docker resource isolation (`deploy.resources` caps, swap
  disable), multi-tenant host hygiene.
- **Landed in:** `docker-compose.prod.yml` (already hardened: `internal_net`
  isolates DB/Redis — aligns with guide's isolation principle).
- **Adaptation:** Guide recommends Coolify + Caddy; TESC uses **GH Actions
  self-hosted runner + nginx** — port the *resource-cap* section only, skip
  Coolify/Caddy. `docker-compose.prod.yml` currently has **no `deploy.resources`
  limits** — this is the actionable gap.
- **Compliance:** [x] internal_net isolation  [x] healthchecks  [ ]
  memory/CPU caps on services  [ ] swap disabled  [ ] staging parity via
  deploy_staging.sh

### 7. Software Security Engineering  → fit: high
- **Ported sections:** multi-tenant/authz isolation, secrets handling, secure
  crypto design, OWASP coverage.
- **Landed in:** `crypto.py`/`decrypt_search.py`, `backend/instauth`,
  `nginx/nginx.conf`, `.env` handling.
- **Adaptation:** Guide's generic; TESC specifics — Fernet key rotation
  (`settings.FERNET_KEYS` is a list — supports rotation), SimpleJWT auth, nginx
  TLS termination. Confirm `DECEMBER`-style secrets-in-env vs vault.
- **Compliance:** [x] DEBUG forced False in prod  [x] internal_net blocks
  external DB access  [ ] Fernet key-rotation runbook  [ ] JWT secret strength
  review  [ ] decrypt endpoint authz audit

### 4. SRE + 5a. Observability  → fit: high (PARTIAL)
- **Ported sections:** SLOs + error budgets; structured logs + error alerting
  (sentry-sdk already in requirements); postmortems.
- **Landed in:** `sentry-sdk` (present in requirements), `docs/PRODUCTION_ARCHITECTURE.md`.
- **Adaptation:** None. sentry-sdk suggests this is partially wired.
- **Compliance:** [x] sentry-sdk present  [ ] SLOs defined  [ ] postmortem
  template  [ ] Redis/Celery queue depth alerting

### 8. E2E Testing  → fit: high (STRONG BASELINE)
- **Ported sections:** CI gating of the test tiers; user-journey coverage.
- **Landed in:** `tests/` (01_smoke … 09_fuzz), `k6` load tests.
- **Adaptation:** Guide assumes Playwright/Cypress UI E2E; TESC has API-level
  pytest tiers + k6 load. Map `tests/08_ui` to guide's E2E tier; ensure gated
  in GH Actions before deploy.
- **Compliance:** [x] smoke/functional/integration/regression  [x] load (k6)
  [x] security + fuzz  [ ] UI E2E gated in CI  [ ] deploy blocked on red tests

### 5b. Secure Application Configuration  → fit: high
- **Ported sections:** env validation at startup, secret rotation, no secrets in
  images.
- **Landed in:** `.env` + `env_file` in compose; `crypto.py` key loading.
- **Adaptation:** Images pull `:${GIT_COMMIT_SHA}` from GHCR — good (no secrets
  baked). Validate all required `.env` vars at Django startup.
- **Compliance:** [x] secrets via env_file (not image)  [ ] startup env
  validation  [ ] FERNET_KEYS rotation documented

### 1. SDLC  → fit: medium (reconcile)
- **Ported sections:** ADR/gate model vs `IMPLEMENTATION_PLAN.md`.
- **Landed in:** `IMPLEMENTATION_PLAN.md`, `docs/system-overview.md`.
- **Adaptation:** TESC already has a plan + docs; promote key decisions to ADR
  format or cross-link to satisfy the gate model.
- **Compliance:** [x] implementation plan  [x] system overview  [ ] ADR
  numbering/status  [ ] explicit quality gates in pipeline

### 3. Mobile App Agent-First  → fit: none
- TESC has no mobile app. Not applicable.

## Open gaps (guides not yet satisfied)

- [ ] 10. Deployment — add `deploy.resources` caps + swap disable to prod compose
- [ ] 4/5a. SRE — define SLOs + postmortem process; Redis/Celery alerting
- [ ] 6. Database — UUIDv7 on new high-volume tables; Postgres stmt timeouts
- [ ] 8. E2E — ensure UI/API tests are hard gates in GH Actions deploy job
- [ ] 7. Security — Fernet key-rotation runbook; decrypt-endpoint authz audit

## Review cadence

Re-open each cycle with `../growth_tracker.md`. If a guide is updated in the
library, re-port changed sections and bump version.

- **Adapter version:** 0.1
- **Last synced:** 2026-07-19
